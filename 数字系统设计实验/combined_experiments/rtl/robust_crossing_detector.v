`timescale 1ns / 1ps
module robust_crossing_detector #(
    parameter integer MIN_HYSTERESIS = 4
) (
    input wire clk, input wire rst_n,
    input wire sample_valid, input wire enable,
    input wire signed [15:0] sample_in,
    output reg rising_event
);
    // Measurement-only FIR: [1 2 1]/4. DC gain is one; at 2 MHz its
    // gain is 0.6545 at 10 MSPS, so the specified band has no notch.
    reg signed [15:0] previous_1, previous_2;
    wire signed [17:0] current_wide = {{2{sample_in[15]}},sample_in};
    wire signed [17:0] previous_1_wide = {{2{previous_1[15]}},previous_1};
    wire signed [17:0] previous_2_wide = {{2{previous_2[15]}},previous_2};
    wire signed [17:0] filtered_q2 = current_wide +
        (previous_1_wide <<< 1) + previous_2_wide;
    wire [17:0] magnitude_q2 = filtered_q2[17] ? -filtered_q2 : filtered_q2;

    // Fast attack / 204.8 us release envelope, in ADC-code Q8 units.
    // Hysteresis follows one quarter of the observed peak, with a floor
    // of +/-4 ADC codes (the old detector used a fixed +/-2 codes).
    reg [23:0] peak_q8;
    wire [23:0] magnitude_q8 = {magnitude_q2,6'b0};
    wire [23:0] release_step = (peak_q8 >> 11) == 0 ? 24'd1 : (peak_q8 >> 11);
    wire [17:0] adaptive_q2 = {2'b00,peak_q8[23:8]};
    localparam [17:0] MINIMUM_Q2 = MIN_HYSTERESIS * 4;
    wire signed [18:0] threshold_q2 = {1'b0,
        adaptive_q2 > MINIMUM_Q2 ? adaptive_q2 : MINIMUM_Q2};
    wire signed [18:0] filtered_wide = {filtered_q2[17],filtered_q2};
    reg armed;
    reg [1:0] holdoff;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            previous_1 <= 0; previous_2 <= 0; peak_q8 <= 0;
            armed <= 0; holdoff <= 0; rising_event <= 0;
        end else begin
            rising_event <= 0;
            if (sample_valid) begin
                previous_1 <= sample_in; previous_2 <= previous_1;
                if (magnitude_q8 >= peak_q8) peak_q8 <= magnitude_q8;
                else if (peak_q8 > release_step) peak_q8 <= peak_q8 - release_step;
                else peak_q8 <= 0;
                if (!enable) begin armed <= 0; holdoff <= 0; end
                else begin
                    if (holdoff != 0) holdoff <= holdoff - 1'b1;
                    if (filtered_wide <= -threshold_q2) armed <= 1;
                    else if (filtered_wide >= threshold_q2 && armed && holdoff == 0) begin
                        armed <= 0; rising_event <= 1; holdoff <= 2;
                    end
                end
            end
        end
    end
endmodule
