`timescale 1ns / 1ps
module adc_conditioner #(
    parameter integer WARMUP_SAMPLES = 50000,
    parameter integer HYSTERESIS = 2
) (
    input wire clk, input wire rst_n, input wire sample_valid,
    input wire [9:0] adc_sample,
    output reg signed [15:0] centered, output reg centered_valid,
    output reg rising_event, output wire settled
);
    // DC estimate in Q12. Time constant 4096 / 10 MHz = 409.6 us.
    reg signed [31:0] dc_q12;
    wire signed [31:0] input_q12 = $signed({1'b0, adc_sample, 12'b0});
    wire signed [31:0] error_q12 = input_q12 - dc_q12;
    wire signed [31:0] rounded_error = (error_q12 + 32'sd2048) >>> 12;
    reg [31:0] warmup;
    reg armed;
    assign settled = warmup >= WARMUP_SAMPLES;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dc_q12 <= 32'sd2097152;
            centered <= 0; centered_valid <= 0; rising_event <= 0;
            warmup <= 0; armed <= 0;
        end else begin
            centered_valid <= 0; rising_event <= 0;
            if (sample_valid) begin
                dc_q12 <= dc_q12 + (error_q12 >>> 12);
                centered <= rounded_error[15:0];
                centered_valid <= 1;
                if (!settled) begin warmup <= warmup + 1'b1; armed <= 0; end
                else if (rounded_error <= -HYSTERESIS) armed <= 1;
                else if (rounded_error >= HYSTERESIS && armed) begin
                    armed <= 0; rising_event <= 1;
                end
            end
        end
    end
endmodule
