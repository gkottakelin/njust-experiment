`timescale 1ns / 1ps
module experiment5b_top #(
    // Same empirical clock-scale calibration as experiments 4 and 5A.
    parameter integer REFERENCE_HZ = 99999500,
    parameter integer GATE_TICKS = 80000000,
    parameter integer TIMEOUT_TICKS = 150000000,
    parameter integer WARMUP_SAMPLES = 50000,
    parameter integer SCAN_SLOT_CYCLES = 100000,
    parameter integer DISPLAY_KHZ = 1,
    parameter integer DAC_SCALE_SHIFT = 5
) (
    input wire clk_in, input wire sys_rst_n, input wire [9:0] ad_in,
    output wire clk_ad,
    output wire [7:0] seg_cs_pin, output wire [7:0] seg_data_0_pin,
    output wire [7:0] seg_data_1_pin,
    output wire clk_da, output reg [7:0] dac_data
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
        .rising_event(rising_event), .settled(settled)
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
    assign clk_da = converter_clk;
    wire signed [15:0] shifted_sample;
    wire shifted_valid, filter_overrun;
    frequency_translate #(.SHIFT_HZ(100000), .REFERENCE_HZ(REFERENCE_HZ)) u_translate (
        .clk(clk_in), .rst_n(rst_n), .sample_valid(centered_valid), .sample_in(centered),
        .output_valid(shifted_valid), .sample_out(shifted_sample), .overrun(filter_overrun)
    );
    wire signed [15:0] interpolated_sample;
    wire interpolated_valid, interpolation_error;
    interpolate_by_five u_dac_interpolator (
        .clk(clk_in), .rst_n(rst_n), .input_valid(shifted_valid), .sample_in(shifted_sample),
        .output_valid(interpolated_valid), .sample_out(interpolated_sample),
        .cadence_error(interpolation_error)
    );
    reg signed [15:0] last_sample;
    // Q4 ADC samples / 32 -> ADC codes / 2: twice the old DAC amplitude,
    // with headroom for the specified 0.5..2 Vpp sine inputs. Shift 6 restores old gain.
    localparam signed [16:0] DAC_ROUND = (17'sd1 << (DAC_SCALE_SHIFT-1));
    wire signed [16:0] dac_rounded =
        ($signed({last_sample[15],last_sample}) + DAC_ROUND) >>> DAC_SCALE_SHIFT;
    wire signed [17:0] dac_signed = $signed({dac_rounded[16],dac_rounded}) + 18'sd128;
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin last_sample <= 0; dac_data <= 128; end
        else begin
            if (interpolated_valid) last_sample <= interpolated_sample;
            if (dac_update) begin
                if (dac_signed < 0) dac_data <= 0;
                else if (dac_signed > 255) dac_data <= 255;
                else dac_data <= dac_signed[7:0];
            end
        end
    end
endmodule
