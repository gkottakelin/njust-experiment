`timescale 1ns / 1ps
module reciprocal_frequency_meter #(
    parameter integer REFERENCE_HZ = 100000000,
    parameter integer GATE_TICKS = 80000000,
    parameter integer TIMEOUT_TICKS = 150000000
) (
    input wire clk, input wire rst_n, input wire rising_event,
    input wire [31:0] timestamp,
    output reg [31:0] frequency_hz, output reg measurement_valid,
    output reg measurement_update
);
    reg tracking;
    reg [31:0] first_edge, last_edge, cycles;
    wire [31:0] elapsed = timestamp - first_edge;
    wire [31:0] silence = timestamp - last_edge;
    wire [31:0] next_cycles = cycles + 1'b1;
    reg divide_start;
    reg [63:0] divide_numerator;
    reg [31:0] divide_denominator;
    wire divide_busy, divide_done;
    wire [63:0] result;
    reg [5:0] multiply_remaining;
    reg [31:0] multiplier;
    reg [63:0] multiplicand, product_acc;
    wire [63:0] next_product = product_acc + (multiplier[0] ? multiplicand : 64'd0);
    unsigned_divider u_divider (
        .clk(clk), .rst_n(rst_n), .start(divide_start),
        .numerator(divide_numerator), .denominator(divide_denominator),
        .busy(divide_busy), .done(divide_done), .quotient(result)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tracking <= 0; first_edge <= 0; last_edge <= 0; cycles <= 0;
            divide_start <= 0; divide_numerator <= 0; divide_denominator <= 1;
            multiply_remaining <= 0; multiplier <= 0; multiplicand <= 0; product_acc <= 0;
            frequency_hz <= 0; measurement_valid <= 0; measurement_update <= 0;
        end else begin
            divide_start <= 0; measurement_update <= 0;
            if (multiply_remaining != 0) begin
                product_acc <= next_product; multiplicand <= multiplicand << 1;
                multiplier <= multiplier >> 1; multiply_remaining <= multiply_remaining - 1'b1;
                if (multiply_remaining == 1) begin divide_numerator <= next_product; divide_start <= 1; end
            end
            if (divide_done && tracking) begin
                frequency_hz <= result[63:32] == 0 ? result[31:0] : 32'd0;
                measurement_valid <= result != 0 && result[63:32] == 0;
                measurement_update <= 1;
            end
            if (rising_event) begin
                last_edge <= timestamp;
                if (!tracking) begin
                    tracking <= 1; first_edge <= timestamp; cycles <= 0;
                end else if (elapsed >= GATE_TICKS && !divide_busy && !divide_start && multiply_remaining == 0) begin
                    // Count complete input periods between two observed crossings.
                    // Add denominator/2 for half-up rounding to integer Hz.
                    product_acc <= {33'd0, elapsed[31:1]};
                    multiplicand <= REFERENCE_HZ; multiplier <= next_cycles; multiply_remaining <= 32;
                    divide_denominator <= elapsed;
                    first_edge <= timestamp; cycles <= 0;
                end else cycles <= next_cycles;
            end else if (tracking && silence >= TIMEOUT_TICKS) begin
                tracking <= 0; cycles <= 0; measurement_valid <= 0;
                frequency_hz <= 0; measurement_update <= 1;
            end
        end
    end
endmodule
