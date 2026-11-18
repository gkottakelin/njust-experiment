`timescale 1ns / 1ps
module frequency_mixer #(
    parameter integer SHIFT_HZ=500000,
    parameter integer REFERENCE_HZ=99999505,
    parameter integer SAMPLE_CLOCK_DIVIDER=10
) (
    input wire clk,input wire rst_n,input wire input_valid,
    input wire signed [15:0] sample_in,
    output reg output_valid,output reg signed [15:0] sample_out
);
    // Sample rate is REFERENCE_HZ / 10, before any filtering or decimation.
    localparam [63:0] STEP_WIDE=(64'd4294967296*SAMPLE_CLOCK_DIVIDER*SHIFT_HZ+REFERENCE_HZ/2)/REFERENCE_HZ;
    reg [31:0] phase;
    wire signed [15:0] cosine;
    cosine_rom u_cosine(.phase(phase[31:22]),.sample(cosine));
    reg signed [31:0] product;
    reg product_valid;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin phase<=0;product<=0;product_valid<=0;output_valid<=0;sample_out<=0;end
        else begin
            product_valid<=input_valid;output_valid<=product_valid;
            if(input_valid)begin phase<=phase+STEP_WIDE[31:0];product<=sample_in*cosine;end
            if(product_valid)sample_out<=(product+32'sd8192)>>>14;
        end
    end
endmodule
