`timescale 1ns / 1ps

module seven_segment_scan #(
    parameter integer SLOT_CYCLES = 50000
) (
    input wire clk,
    input wire rst_n,
    input wire [1:0] mode,
    input wire [31:0] frequency_bcd,
    output reg [7:0] seg_cs_pin,
    output reg [7:0] seg_data_0_pin,
    output reg [7:0] seg_data_1_pin
);
    // Segment bits [7:0] = {dp,g,f,e,d,c,b,a}; all outputs active high.
    // Board groups DN0 (left) and DN1 (right), K1 through K4 left to right.
    reg [31:0] slot_count;
    reg [2:0] scan_index;
    reg [31:0] frame_digits;
    reg [7:0] frame_dp;
    reg frame_enabled;
    wire [3:0] character = (frame_digits >> ((7-scan_index)*4)) & 4'hf;
    wire [7:0] segments = {frame_dp[scan_index], decode(character)};

    function [6:0] decode;
        input [3:0] value;
        begin
            case (value)
                4'd0: decode = 7'b0111111;
                4'd1: decode = 7'b0000110;
                4'd2: decode = 7'b1011011;
                4'd3: decode = 7'b1001111;
                4'd4: decode = 7'b1100110;
                4'd5: decode = 7'b1101101;
                4'd6: decode = 7'b1111101;
                4'd7: decode = 7'b0000111;
                4'd8: decode = 7'b1111111;
                4'd9: decode = 7'b1101111;
                4'ha: decode = 7'b0001000; // underscore
                default: decode = 7'b0000000;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slot_count <= 0;
            scan_index <= 0;
            frame_digits <= 32'h2610a652;
            frame_dp <= 8'b00000010;
            frame_enabled <= 1'b1;
            seg_cs_pin <= 0;
            seg_data_0_pin <= 0;
            seg_data_1_pin <= 0;
        end else begin
            if (slot_count == SLOT_CYCLES-1) begin
                slot_count <= 0;
                scan_index <= scan_index + 1'b1;
            end else
                slot_count <= slot_count + 1'b1;

            // Blank, change segments, then enable the next digit to avoid ghosting.
            if (slot_count == 0) begin
                seg_cs_pin <= 0;
                if (scan_index == 0) begin
                    frame_enabled <= (mode == 2'b00 || mode == 2'b01);
                    if (mode == 2'b01) begin
                        frame_digits <= frequency_bcd;
                        frame_dp <= 8'b00010000; // fifth digit from left
                    end else begin
                        frame_digits <= 32'h2610a652;
                        frame_dp <= 8'b00000010; // second digit from left
                    end
                end
            end
            if (slot_count == 1) begin
                seg_data_0_pin <= scan_index < 4 ? segments : 8'd0;
                seg_data_1_pin <= scan_index >= 4 ? segments : 8'd0;
            end
            if (slot_count == 2)
                seg_cs_pin <= frame_enabled ? (8'b1 << scan_index) : 8'd0;
        end
    end
endmodule
