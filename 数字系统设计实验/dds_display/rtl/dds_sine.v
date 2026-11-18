`timescale 1ns / 1ps

// 100 MHz system clock, 10 MHz phase-update enable and 10 MHz DAC clock.
// Updating data on the DAC falling edge gives 50 ns before its rising edge.
module dds_sine (
    input wire clk,
    input wire rst_n,
    input wire [7:0] tuning_word,
    output reg clk_da,
    output reg [7:0] sin_out
);
    reg [3:0] divider;
    reg [7:0] phase;
    wire [7:0] next_phase = phase + tuning_word;
    wire [7:0] next_sample;
    sine_rom u_sine_rom (.phase(next_phase), .sample(next_sample));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divider <= 0;
            phase <= 0;
            clk_da <= 0;
            sin_out <= 8'd128;
        end else begin
            divider <= divider == 9 ? 4'd0 : divider + 1'b1;
            if (divider == 0) begin
                clk_da <= 1'b0;
                phase <= next_phase;
                sin_out <= next_sample;
            end
            if (divider == 5)
                clk_da <= 1'b1;
        end
    end
endmodule
