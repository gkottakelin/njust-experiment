`timescale 1ns / 1ps
module unsigned_divider (
    input wire clk, input wire rst_n, input wire start,
    input wire [63:0] numerator, input wire [31:0] denominator,
    output reg busy, output reg done, output reg [63:0] quotient
);
    reg [63:0] dividend;
    reg [31:0] divisor;
    reg [32:0] remainder;
    reg [6:0] remaining;
    wire [32:0] trial = {remainder[31:0], dividend[63]};
    wire subtract = trial >= {1'b0, divisor};
    wire [32:0] next_remainder = subtract ? trial - {1'b0, divisor} : trial;
    wire [63:0] next_quotient = {quotient[62:0], subtract};
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0; done <= 0; quotient <= 0; dividend <= 0;
            divisor <= 1; remainder <= 0; remaining <= 0;
        end else begin
            done <= 0;
            if (start && !busy) begin
                dividend <= numerator; divisor <= denominator;
                quotient <= 0; remainder <= 0; remaining <= 64;
                if (denominator != 0) busy <= 1;
                else begin quotient <= 0; done <= 1; end
            end else if (busy) begin
                dividend <= {dividend[62:0], 1'b0};
                remainder <= next_remainder; quotient <= next_quotient;
                remaining <= remaining - 1'b1;
                if (remaining == 1) begin busy <= 0; done <= 1; end
            end
        end
    end
endmodule
