`timescale 1ns / 1ps
module tb_frontend_display;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0;
    reg [9:0] ad_in=512;
    wire adc_clk, adc_valid, dac_update;
    wire [9:0] adc_sample;
    sample_clocking sampler(.clk(clk),.rst_n(rst_n),.ad_in(ad_in),.converter_clk(adc_clk),
        .adc_sample(adc_sample),.adc_valid(adc_valid),.dac_update(dac_update));
    wire signed [15:0] centered;
    wire centered_valid, rising_event, settled;
    adc_conditioner conditioner(.clk(clk),.rst_n(rst_n),.sample_valid(adc_valid),.adc_sample(adc_sample),
        .centered(centered),.centered_valid(centered_valid),.rising_event(rising_event),.settled(settled));
    wire [7:0] cs,seg0,seg1;
    reg [31:0] shown_hz=2000000;
    reg shown_valid=0;
    measured_frequency_display #(.SLOT_CYCLES(20)) display_dut(
        .clk(clk),.rst_n(rst_n),.frequency_hz(shown_hz),.measurement_valid(shown_valid),
        .seg_cs_pin(cs),.seg_data_0_pin(seg0),.seg_data_1_pin(seg1));
    real phase=0, frequency=100, amplitude=64, bias=717;
    integer code, next_code, pipeline0=512,pipeline1=512,pipeline2=512;
    time last_converter_edge=0;
    always @(adc_clk) if (rst_n) begin
        if(last_converter_edge!=0 && $time-last_converter_edge!=50) $fatal(1,"ADC clock half-period is not 50 ns");
        last_converter_edge=$time;
    end
    always @(negedge adc_clk) begin
        code=$rtoi($floor(bias+amplitude*$sin(phase)+0.5));
        phase=phase+6.283185307179586*frequency/10000000.0;
        if(phase>=6.283185307179586)phase=phase-6.283185307179586;
        next_code=pipeline2;pipeline2=pipeline1;pipeline1=pipeline0;pipeline0=code;
        #25;ad_in=next_code;
    end
    time first_cross=0,last_cross=0;
    integer crossings=0;
    reg collect=0;
    always @(posedge rising_event) if(collect)begin
        if(crossings==0)first_cross=$time;
        last_cross=$time;crossings=crossings+1;
    end
    task automatic check_conditioner(input real f,input real a,input real b,input integer duration_ns);
        real measured,error;
        begin
            collect=0;frequency=f;amplitude=a;bias=b;
            #5000000; // 5 ms settling after changing amplitude and DC offset.
            crossings=0;collect=1;
            #(duration_ns);collect=0;
            if(crossings<2)$fatal(1,"No crossings at %f Hz",f);
            measured=(crossings-1)*1000000000.0/(last_cross-first_cross);
            error=measured-f;if(error<0)error=-error;
            if(error>f*0.0001+0.1)$fatal(1,"Crossing detector error: %f vs %f",measured,f);
            $display("FRONTEND: %f Hz, ADC amplitude=%f bias=%f, crossings=%0d",f,a,b,crossings);
        end
    endtask
    function automatic [6:0] segments(input [3:0] value);
        case(value)
        0:segments=7'h3f;1:segments=7'h06;2:segments=7'h5b;3:segments=7'h4f;
        4:segments=7'h66;5:segments=7'h6d;6:segments=7'h7d;7:segments=7'h07;
        8:segments=7'h7f;9:segments=7'h6f;default:segments=7'h40;
        endcase
    endfunction
    task automatic check_display(input [31:0] digits,input bit valid_value);
        integer i;
        reg[7:0] expected;
        begin
            shown_valid=valid_value;
            repeat(400)@(negedge clk);
            wait(cs==0);wait(cs==1);
            for(i=0;i<8;i=i+1)begin
                wait(cs==(8'b1<<i));#1;
                expected={valid_value && i==4,segments((digits>>((7-i)*4))&15)};
                if(i<4)begin if(seg0!==expected || seg1!==0)$fatal(1,"Left display digit mismatch");end
                else if(seg1!==expected || seg0!==0)$fatal(1,"Right display digit mismatch");
                wait(cs==0);
            end
        end
    endtask
    reg [7:0] last_cs=0;
    always @(negedge clk)begin
        if((cs&(cs-1'b1))!=0)$fatal(1,"Multiple digit selects");
        if(cs!=0 && last_cs!=0 && cs!=last_cs)$fatal(1,"Missing digit blanking");
        last_cs=cs;
    end
    initial begin
        #35;rst_n=1;
        check_display(32'hffffffff,0);
        check_display(32'h02000000,1);
        shown_hz=100;check_display(32'h00000100,1);
        check_conditioner(100.0,64,717,30000000);
        check_conditioner(1000.0,256,307,5000000);
        check_conditioner(500000.0,64,717,3000000);
        check_conditioner(2000000.0,256,307,3000000);
        collect=0;frequency=0;amplitude=0;bias=820;
        #5000000;crossings=0;collect=1;#1000000;
        if(crossings!=0)$fatal(1,"False crossings on DC input");
        $display("PASS: 10 MSPS timing, 25 ns ADC model, bipolar DC offsets, 100 Hz to 2 MHz crossings, constant input, BCD, decimal position and scan blanking");
        $finish;
    end
    initial begin #100000000;$fatal(1,"Frontend test timeout");end
endmodule
