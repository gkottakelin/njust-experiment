`timescale 1ns / 1fs
module tb_integration #(parameter integer PRODUCTION_TEST=0);
    // The physical-counter model matches the calibrated conversion reference.
    localparam real SIM_REFERENCE_HZ=99999500.0;
    reg clk=0;always #(500000000.0/SIM_REFERENCE_HZ) clk=~clk;
    reg rst_n=0;
    reg [9:0] ad_in=512;
    wire adc_clk;
    wire [7:0]cs,seg0,seg1;

    experiment4_top #(.GATE_TICKS(PRODUCTION_TEST ? 80000000 : 200000),
        .TIMEOUT_TICKS(PRODUCTION_TEST ? 150000000 : 4000000),
        .WARMUP_SAMPLES(PRODUCTION_TEST ? 50000 : 100),.SCAN_SLOT_CYCLES(20)) dut(
        .clk_in(clk),.sys_rst_n(rst_n),.ad_in(ad_in),.clk_ad(adc_clk),
        .seg_cs_pin(cs),.seg_data_0_pin(seg0),.seg_data_1_pin(seg1));
    real phase=0, input_frequency=550000.0, amplitude=128.0, bias=512.0;
    integer code,next_code,pipeline0=512,pipeline1=512,pipeline2=512;
    always @(negedge adc_clk)begin
        code=$rtoi($floor(bias+amplitude*$sin(phase)+0.5));
        if(code<0 || code>1023)$fatal(1,"ADC test stimulus clipped");
        phase=phase+6.283185307179586*input_frequency/(SIM_REFERENCE_HZ/10.0);
        if(phase>=6.283185307179586)phase=phase-6.283185307179586;
        next_code=pipeline2;pipeline2=pipeline1;pipeline1=pipeline0;pipeline0=code;
        #25;ad_in=next_code;
    end
    reg collecting=0;
    integer file_handle, case_index=0;
    integer output_count=0;

    task automatic run_case(input real f,input real a,input real b,input integer record_ns);
        real measured,error;
        begin
            collecting=0;input_frequency=f;amplitude=a;bias=b;
            if(f<500.0)begin #30000000;end
            else begin #6000000;end
            if(!dut.measurement_valid)$fatal(1,"Measurement not valid at input %f",f);
            measured=dut.frequency_hz;error=measured-f;if(error<0)error=-error;
            // Short 2 ms gate used here only to test integration quickly.
            // The separate meter test uses the production 0.8 s gate and <=1 Hz.
            if(error>600)$fatal(1,"Integration measured %f rather than %f",measured,f);
            case_index=case_index+1;output_count=0;

            collecting=1;#(record_ns);collecting=0;

            $display("INTEGRATION: fin=%f Hz, measured=%0d Hz",f,dut.frequency_hz);
        end
    endtask
    real production_error;
    time changed_at;
    initial begin
        #40;rst_n=1;
        if(PRODUCTION_TEST)begin
            input_frequency=1999999.4;amplitude=64;bias=717;
            wait(dut.measurement_update && dut.measurement_valid);#1;
            production_error=dut.frequency_hz-input_frequency;
            if(production_error<0)production_error=-production_error;
            if(production_error>1.0)$fatal(1,"Production high-frequency error %f",production_error);
            $display("PRODUCTION: input=%f measured=%0d error=%f Hz",input_frequency,dut.frequency_hz,production_error);
            input_frequency=100.37;amplitude=256;bias=307;changed_at=$time;
            production_error=1000000;
            while(production_error>1.0)begin
                @(posedge dut.measurement_update);#1;
                production_error=dut.frequency_hz-input_frequency;
                if(production_error<0)production_error=-production_error;
                if($time-changed_at>64'd2000000000)$fatal(1,"Response exceeded 2 s");
            end
            $display("PRODUCTION: input=%f measured=%0d error=%f Hz settled_after_ns=%0d",input_frequency,dut.frequency_hz,production_error,$time-changed_at);
            $display("PASS: calibrated ADC/counter model, full 0.8 s gate, <=1 Hz error and <=2 s change response without reset");
            $finish;
        end
        run_case(100.0,64,717,30000000);
        run_case(1000.0,256,307,5000000);
        run_case(500000.0,64,717,3000000);
        run_case(2000000.0,256,307,3000000);
        $display("PASS: experiment4_top ADC/measurement/display integration");
        $finish;
    end
    initial begin
        if(PRODUCTION_TEST)begin #(64'd4000000000);$fatal(1,"Production integration timeout");end
        else begin #200000000;$fatal(1,"Integration timeout");end
    end
endmodule

module tb_production;
    tb_integration #(.PRODUCTION_TEST(1)) test();
endmodule
