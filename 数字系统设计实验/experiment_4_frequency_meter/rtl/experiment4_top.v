`timescale 1ns / 1ps
module experiment4_top #(
    // Empirical -5 ppm conversion correction; the physical clock is unchanged.
    parameter integer REFERENCE_HZ = 99999500,
    parameter integer GATE_TICKS = 80000000,
    parameter integer TIMEOUT_TICKS = 150000000,
    parameter integer WARMUP_SAMPLES = 50000,
    parameter integer SCAN_SLOT_CYCLES = 100000,
    parameter integer DISPLAY_KHZ = 1
) (
    input wire clk_in, input wire sys_rst_n, input wire [9:0] ad_in,
    output wire clk_ad,
    output wire [7:0] seg_cs_pin, output wire [7:0] seg_data_0_pin,
    output wire [7:0] seg_data_1_pin
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync = 2'b00;
    always @(posedge clk_in or negedge sys_rst_n)
        if (!sys_rst_n) reset_sync <= 0;
        else reset_sync <= {reset_sync[0],1'b1};
    wire rst_n = reset_sync[1];
    reg [31:0] timestamp;
    always @(posedge clk_in or negedge rst_n)
        if (!rst_n) timestamp <= 0;
        else timestamp <= timestamp + 1'b1;
    wire [9:0] adc_sample;
    wire adc_valid, dac_update, converter_clk;
    sample_clocking u_sampling (
        .clk(clk_in), .rst_n(rst_n), .ad_in(ad_in), .converter_clk(converter_clk),
        .adc_sample(adc_sample), .adc_valid(adc_valid), .dac_update(dac_update)
    );
    assign clk_ad = converter_clk;
    wire signed [15:0] centered;
    wire centered_valid, rising_event, settled;
    adc_conditioner #(.WARMUP_SAMPLES(WARMUP_SAMPLES)) u_conditioner (
        .clk(clk_in), .rst_n(rst_n), .sample_valid(adc_valid), .adc_sample(adc_sample),
        .centered(centered), .centered_valid(centered_valid),
        .rising_event(), .settled(settled)
    );
    robust_crossing_detector u_crossing (
        .clk(clk_in), .rst_n(rst_n), .sample_valid(centered_valid), .enable(settled),
        .sample_in(centered), .rising_event(rising_event)
    );
    wire [31:0] frequency_hz;
    wire measurement_valid, measurement_update;
    reciprocal_frequency_meter #(.REFERENCE_HZ(REFERENCE_HZ), .GATE_TICKS(GATE_TICKS),
        .TIMEOUT_TICKS(TIMEOUT_TICKS)) u_meter (
        .clk(clk_in), .rst_n(rst_n), .rising_event(rising_event), .timestamp(timestamp),
        .frequency_hz(frequency_hz), .measurement_valid(measurement_valid),
        .measurement_update(measurement_update)
    );
    measured_frequency_display #(.SLOT_CYCLES(SCAN_SLOT_CYCLES), .DISPLAY_KHZ(DISPLAY_KHZ)) u_display (
        .clk(clk_in), .rst_n(rst_n), .frequency_hz(frequency_hz), .measurement_valid(measurement_valid),
        .seg_cs_pin(seg_cs_pin), .seg_data_0_pin(seg_data_0_pin), .seg_data_1_pin(seg_data_1_pin)
    );

endmodule
