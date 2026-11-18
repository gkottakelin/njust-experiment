`timescale 1ns / 1ps
module frequency_translate #(
    parameter integer SHIFT_HZ = 500000,
    parameter integer REFERENCE_HZ = 100000000
) (
    input wire clk, input wire rst_n, input wire sample_valid,
    input wire signed [15:0] sample_in,
    output wire output_valid, output wire signed [15:0] sample_out,
    output wire overrun
);
    // Preserve four fractional bits through decimation, mixing and filtering.
    wire signed [15:0] input_q4 = sample_in <<< 4;
    wire decimated_valid;
    wire signed [15:0] decimated;
    decimate_by_five u_decimator (
        .clk(clk), .rst_n(rst_n), .input_valid(sample_valid), .sample_in(input_q4),
        .output_valid(decimated_valid), .sample_out(decimated)
    );
    // 2 MHz nominal DSP rate; tune against a calibrated system-clock value if known.
    localparam [63:0] STEP_WIDE = (64'd214748364800 * SHIFT_HZ + REFERENCE_HZ/2) / REFERENCE_HZ;
    reg [31:0] lo_phase;
    wire signed [15:0] lo_cos;
    cosine_rom u_cosine (.phase(lo_phase[31:22]), .sample(lo_cos));
    reg signed [31:0] mixed_product;
    reg product_valid;
    reg signed [15:0] mixed_sample;
    reg mixed_valid;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lo_phase <= 0; mixed_product <= 0; product_valid <= 0;
            mixed_sample <= 0; mixed_valid <= 0;
        end else begin
            product_valid <= decimated_valid; mixed_valid <= product_valid;
            if (decimated_valid) begin
                lo_phase <= lo_phase + STEP_WIDE[31:0];
                mixed_product <= decimated * lo_cos;
            end
            if (product_valid) mixed_sample <= (mixed_product + 32'sd8192) >>> 14;
        end
    end
    translation_fir u_filter (
        .clk(clk), .rst_n(rst_n), .input_valid(mixed_valid), .sample_in(mixed_sample),
        .output_valid(output_valid), .sample_out(sample_out), .overrun(overrun)
    );
endmodule
