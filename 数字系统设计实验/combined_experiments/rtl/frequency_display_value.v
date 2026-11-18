`timescale 1ns / 1ps

// BCD value is integer Hz: displaying three fractional kHz digits is exact.
// Half-up rounding: round(K * 10_000_000 / 256) = (K * 78_125 + 1) / 2.
module frequency_display_value (
    input wire clk,
    input wire rst_n,
    input wire [7:0] tuning_word,
    output reg [31:0] bcd
);
    wire [24:0] twice_hz = tuning_word * 25'd78125 + 25'd1;
    reg [23:0] binary_work;
    reg [31:0] bcd_work;
    reg [4:0] remaining;
    reg [31:0] adjusted;
    integer digit;

    always @* begin
        adjusted = bcd_work;
        for (digit = 0; digit < 8; digit = digit + 1)
            if (bcd_work[digit*4 +: 4] >= 4'd5)
                adjusted[digit*4 +: 4] = bcd_work[digit*4 +: 4] + 4'd3;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            binary_work <= 24'd0;
            bcd_work <= 32'd0;
            remaining <= 5'd0;
            bcd <= 32'd0;
        end else if (remaining == 0) begin
            binary_work <= twice_hz[24:1];
            bcd_work <= 32'd0;
            remaining <= 5'd24;
        end else begin
            binary_work <= {binary_work[22:0], 1'b0};
            bcd_work <= {adjusted[30:0], binary_work[23]};
            remaining <= remaining - 1'b1;
            if (remaining == 1)
                bcd <= {adjusted[30:0], binary_work[23]};
        end
    end
endmodule
