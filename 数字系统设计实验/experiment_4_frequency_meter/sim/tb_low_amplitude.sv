`timescale 1ns / 1fs
module tb_low_amplitude;
    localparam real SIM_REFERENCE_HZ=99999500.0;
    reg clk=0; always #(500000000.0/SIM_REFERENCE_HZ) clk=~clk;
    reg rst_n=0;
    reg [9:0] ad_in=512;
    wire adc_clk;
    wire [7:0] cs,seg0,seg1;
    experiment4_top #(.SCAN_SLOT_CYCLES(20)) dut (
        .clk_in(clk),.sys_rst_n(rst_n),.ad_in(ad_in),.clk_ad(adc_clk),
        .seg_cs_pin(cs),.seg_data_0_pin(seg0),.seg_data_1_pin(seg1));
    wire [31:0] legacy_hz;
    wire legacy_valid,legacy_update;
    reciprocal_frequency_meter #(.REFERENCE_HZ(99999500),.GATE_TICKS(80000000)) legacy_meter (
        .clk(clk),.rst_n(dut.rst_n),.timestamp(dut.timestamp),
        .rising_event(dut.u_conditioner.rising_event),.frequency_hz(legacy_hz),
        .measurement_valid(legacy_valid),.measurement_update(legacy_update));
    real phase=0, amplitude=128.0;
    real noise_rms=1.2;
    integer seed=20261022;
    integer code,next_code,pipe0=512,pipe1=512,pipe2=512;
    real noise;
    always @(negedge adc_clk) begin
        noise=$dist_normal(seed,0,1200)/1000.0;
        code=$rtoi($floor(512.0+amplitude*$sin(phase)+noise+0.5));
        if(code<0 || code>1023)$fatal(1,"ADC stimulus clipped");
        phase=phase+6.283185307179586*100000.0/(SIM_REFERENCE_HZ/10.0);
        if(phase>=6.283185307179586)phase=phase-6.283185307179586;
        next_code=pipe2;pipe2=pipe1;pipe1=pipe0;pipe0=code;
        #25;ad_in=next_code;
    end
    real error_hz;
    task automatic check_new(input integer window_index);
        begin
            @(posedge dut.measurement_update);#1;
            error_hz=$signed(dut.frequency_hz)-100000.0;
            if(error_hz<0)error_hz=-error_hz;
            if(!dut.measurement_valid || error_hz>1.0)
                $fatal(1,"Noisy low-amplitude frequency error %f Hz",error_hz);
            $display("LOW_AMPLITUDE: window=%0d external_vpp=%f ADC_noise_rms=1.2_codes new=%0d old_latest=%0d new_error=%f Hz",
                window_index,amplitude/128.0,dut.frequency_hz,legacy_hz,error_hz);
        end
    endtask
    initial begin
        #40;rst_n=1;
        check_new(0); // 1.0 Vpp, production 0.8 s gate, calibrated counter model.
        if(!legacy_valid || legacy_hz<99999 || legacy_hz>100001)
            $fatal(1,"High-amplitude reference case did not reproduce an accurate old reading");
        amplitude=32.0; // 0.25 Vpp -> +/-32 codes after 0.5x analog front end.
        check_new(1);
        check_new(2); // Entire window at 0.25 Vpp, without resetting either meter.
        // Wait for the old window to finish; extra crossings move its boundaries.
        @(posedge legacy_update);#1;
        $display("LOW_AMPLITUDE_LEGACY: external_vpp=0.25 frequency=%0d error=%0d Hz",legacy_hz,$signed(legacy_hz)-100000);
        if(legacy_hz>=99990 && legacy_hz<=100010)
            $fatal(1,"Noise did not exercise the old false-crossing failure");
        $display("PASS: 100 kHz, 1.0/0.25 Vpp, 1.2 ADC-code RMS noise, 0.8 s gate and calibrated counter model, <=1 Hz new error; legacy false-crossing error reproduced");
        $finish;
    end
    initial begin #(64'd6000000000);$fatal(1,"Low-amplitude simulation timeout");end
endmodule
