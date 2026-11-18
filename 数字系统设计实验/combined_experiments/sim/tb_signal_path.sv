`timescale 1ns / 1fs
// Verify received-signal translation independently of frequency measurement or DDS.
module tb_signal_path;
    localparam real REFERENCE=99999505.0;
    localparam real PI=3.141592653589793;
    reg clk=0;
    integer clock_edge_number=0;
    initial forever begin
        clock_edge_number=clock_edge_number+1;
        #(clock_edge_number*500000000.0/REFERENCE-$realtime)clk=~clk;
    end
    reg sys_rst_n=0;
    reg [7:0] dip=8'h10;
    reg [9:0] ad_in=512;
    wire adc_clk,dac_clk;
    wire [7:0] dac_reference,dac_poisoned;
    combined_experiments_top reference_dut(
        .clk_in(clk),.sys_rst_n(sys_rst_n),.rst(1'b0),.sw(8'd1),.dip(dip),.ad_in(ad_in),
        .clk_ad(adc_clk),.clk_da(dac_clk),.dac_data(dac_reference));
    // Different DDS setting; corrupt its measured frequency and measurement_valid below.
    combined_experiments_top poisoned_dut(
        .clk_in(clk),.sys_rst_n(sys_rst_n),.rst(1'b0),.sw(8'd255),.dip(dip),.ad_in(ad_in),
        .dac_data(dac_poisoned));

    real amplitude1=0,amplitude2=0,frequency1=550000.0,frequency2=570000.0,phase_offset=0;
    real time_seconds,sample_value;
    integer code,next_code,pipe0=512,pipe1=512,pipe2=512;
    always @(negedge adc_clk)begin
        time_seconds=$realtime*1.0e-9;
        sample_value=512.0+amplitude1*$sin(2*PI*frequency1*time_seconds+phase_offset)
            +amplitude2*$sin(2*PI*frequency2*time_seconds+0.37);
        code=$rtoi($floor(sample_value+0.5));
        if(code<0 || code>1023)$fatal(1,"ADC model clipping");
        next_code=pipe2;pipe2=pipe1;pipe1=pipe0;pipe0=code;
        #25;ad_in=next_code;
    end
    integer compared_samples=0;
    always @(posedge dac_clk)if(reference_dut.rst_n && (reference_dut.active_mode==8'h10 || reference_dut.active_mode==8'h11) &&
                               reference_dut.mute_count==0 && poisoned_dut.mute_count==0)begin
        if(dac_reference!==dac_poisoned)
            $fatal(1,"Measured frequency/valid or unrelated DDS setting affected translated DAC data");
        if(reference_dut.overrun_5a || reference_dut.overrun_5b ||
           poisoned_dut.overrun_5a || poisoned_dut.overrun_5b)
            $fatal(1,"Filter throughput or interpolation cadence error");
        compared_samples=compared_samples+1;
    end
    integer file_handle,case_number=0,capture_count=0;
    reg collecting=0;
    always @(posedge dac_clk)if(collecting)begin
        $fdisplay(file_handle,"%0.6f,%0d,%0d",$realtime,dac_reference,dac_poisoned);
        capture_count=capture_count+1;
    end
    task automatic capture(input [7:0] mode,input integer kind,input integer duration_ns);
        begin
            // Full production parameters remain in both DUTs. A 1 ms wait also
            // drains the actual ADC/mixer/FIR/interpolator histories between inputs.
            #1000000;
            case_number=case_number+1;capture_count=0;
            file_handle=$fopen($sformatf("signal_path_case_%0d.csv",case_number),"w");
            if(!file_handle)$fatal(1,"Cannot open signal path output");
            $fdisplay(file_handle,"time_ns,dac_reference,dac_poisoned");
            collecting=1;#(duration_ns);collecting=0;$fclose(file_handle);
            if(capture_count<9000)$fatal(1,"Insufficient samples");
            $display("SIGNAL_PATH: case=%0d mode=%0d kind=%0d samples=%0d",case_number,mode,kind,capture_count);
        end
    endtask
    task automatic run_mode(input [7:0] mode);
        begin
            amplitude1=0;amplitude2=0;phase_offset=0;frequency1=550000.0;
            dip=mode;
            wait(reference_dut.active_mode==mode && poisoned_dut.active_mode==mode);
            // A fabricated valid measurement must not create an output tone.
            force poisoned_dut.frequency_hz=32'd1234567;
            force poisoned_dut.measurement_valid=1'b1;
            capture(mode,0,1000000);
            amplitude1=96;
            capture(mode,1,2000000);
            amplitude1=48;
            capture(mode,2,2000000);
            amplitude1=96;phase_offset=PI;
            // Make the measurement unavailable. The received waveform must continue.
            force poisoned_dut.frequency_hz=32'd0;
            force poisoned_dut.measurement_valid=1'b0;
            capture(mode,3,2000000);
            amplitude1=64;amplitude2=48;frequency1=530000.0;phase_offset=0;
            force poisoned_dut.frequency_hz=32'd9876543;
            force poisoned_dut.measurement_valid=1'b1;
            capture(mode,4,4000000);
            amplitude1=0;amplitude2=0;
            capture(mode,5,1000000);
        end
    endtask
    initial begin
        #40;sys_rst_n=1;
        run_mode(8'h10);run_mode(8'h11);
        if(case_number!=12 || compared_samples<250000)$fatal(1,"Signal-path coverage incomplete");
        $display("PASS: 5A/5B full received-signal paths; %0d physical DAC samples identical despite corrupt measured frequencies, measurement validity and independent DDS settings; production parameters retained",compared_samples);
        $finish;
    end
    initial begin #100000000;$fatal(1,"Signal path test timeout");end
endmodule
