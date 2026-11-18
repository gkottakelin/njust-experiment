`timescale 1ns / 1fs
module tb_integration;
    localparam real SIM_REFERENCE_HZ=99999500.0;
    reg clk=0;always #(500000000.0/SIM_REFERENCE_HZ) clk=~clk;
    reg rst_n=0;
    reg [9:0] ad_in=512;
    wire adc_clk;
    wire [7:0]cs,seg0,seg1;
    wire dac_clk;wire[7:0]dac_data;
    experiment5a_top #(.GATE_TICKS(200000),.TIMEOUT_TICKS(4000000),.WARMUP_SAMPLES(100),.SCAN_SLOT_CYCLES(20)) dut(
        .clk_in(clk),.sys_rst_n(rst_n),.ad_in(ad_in),.clk_ad(adc_clk),
        .seg_cs_pin(cs),.seg_data_0_pin(seg0),.seg_data_1_pin(seg1),.clk_da(dac_clk),.dac_data(dac_data));
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
    integer file_handle, dac_file_handle, case_index=0;
    integer dac_output_count=0, last_interp_cycle=-1, system_cycles=0;
    always @(posedge clk) system_cycles<=system_cycles+1;
    always @(posedge dut.interpolated_valid) begin
        #0.001;
        if(last_interp_cycle>=0 && system_cycles-last_interp_cycle!=10)
            $fatal(1,"Interpolation did not supply one sample every DAC clock");
        last_interp_cycle=system_cycles;
    end
    always @(posedge dac_clk) if(collecting)begin
        $fdisplay(dac_file_handle,"%0.6f,%0d",$realtime,dac_data);
        dac_output_count=dac_output_count+1;
    end
    integer output_count=0;
    always @(negedge clk)begin
        if(dut.filter_overrun || dut.interpolation_error)$fatal(1,"FIR MAC did not finish before next sample");
        if(collecting && dut.shifted_valid)begin
            // Preserve sub-nanosecond timestamps for independent ppm verification.
            $fdisplay(file_handle,"%0.6f,%0d,%0d",$realtime,$signed(dut.shifted_sample),dac_data);
            output_count=output_count+1;
        end
    end
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
            case_index=case_index+1;output_count=0;dac_output_count=0;
            file_handle=$fopen($sformatf("translated_case_%0d.csv",case_index),"w");
            dac_file_handle=$fopen($sformatf("dac_case_%0d.csv",case_index),"w");
            if(!file_handle || !dac_file_handle)$fatal(1,"Cannot open sample log");
            $fdisplay(dac_file_handle,"time_ns,dac_code");
            $fdisplay(file_handle,"time_ns,filtered_sample_q4,subsampled_dac_code");
            collecting=1;#(record_ns);collecting=0;
            $fclose(file_handle);$fclose(dac_file_handle);
            if(dac_output_count<5*output_count-6 || dac_output_count>5*output_count+6)
                $fatal(1,"Full DAC stream did not contain five samples per DSP result");
            if(output_count<4000)$fatal(1,"Too few translated samples");
            $display("INTEGRATION: fin=%f Hz, measured=%0d Hz",f,dut.frequency_hz);
        end
    endtask
    initial begin
        #40;rst_n=1;
        run_case(500000.0,128,512,5000000);
        run_case(500100.0,64,717,45000000);
        run_case(525123.45,256,307,10000000);
        run_case(600000.0,128,717,10000000);
        $display("PASS: experiment5a_top with calibrated clock model, ADC/measurement/display integration and actual mixing/FIR streaming");
        $finish;
    end
    initial begin #200000000;$fatal(1,"Integration timeout");end
endmodule
