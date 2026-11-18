`timescale 1ns / 1ps
module measured_frequency_display #(
    parameter integer SLOT_CYCLES = 100000,
    parameter integer DISPLAY_KHZ = 1
) (
    input wire clk, input wire rst_n, input wire [31:0] frequency_hz,
    input wire measurement_valid,
    output reg [7:0] seg_cs_pin,
    output reg [7:0] seg_data_0_pin, output reg [7:0] seg_data_1_pin
);
    // Integer Hz displayed with three decimal kHz places: no conversion loss.
    reg [31:0] binary_work, bcd_work, bcd;
    reg [5:0] remaining;
    reg [31:0] adjusted;
    integer n;
    always @* begin
        adjusted = bcd_work;
        for (n = 0; n < 8; n = n + 1)
            if (bcd_work[n*4 +: 4] >= 5)
                adjusted[n*4 +: 4] = bcd_work[n*4 +: 4] + 4'd3;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin binary_work <= 0; bcd_work <= 0; bcd <= 0; remaining <= 0; end
        else if (remaining == 0) begin
            binary_work <= frequency_hz; bcd_work <= 0; remaining <= 32;
        end else begin
            binary_work <= {binary_work[30:0], 1'b0};
            bcd_work <= {adjusted[30:0], binary_work[31]};
            remaining <= remaining - 1'b1;
            if (remaining == 1) bcd <= {adjusted[30:0], binary_work[31]};
        end
    end
    reg [31:0] frame_digits;
    reg frame_valid;
    reg [31:0] slot_count;
    reg [2:0] index;
    wire [3:0] character = (frame_digits >> ((7-index)*4)) & 4'hf;
    wire [7:0] segments = {((DISPLAY_KHZ != 0) && frame_valid && index == 4), decode(character)};
    function [6:0] decode;
        input [3:0] value;
        begin
            case (value)
                0: decode = 7'h3f; 1: decode = 7'h06; 2: decode = 7'h5b;
                3: decode = 7'h4f; 4: decode = 7'h66; 5: decode = 7'h6d;
                6: decode = 7'h7d; 7: decode = 7'h07; 8: decode = 7'h7f;
                9: decode = 7'h6f; default: decode = 7'h40; // dash
            endcase
        end
    endfunction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_digits <= 32'hffffffff; frame_valid <= 0; slot_count <= 0; index <= 0;
            seg_cs_pin <= 0; seg_data_0_pin <= 0; seg_data_1_pin <= 0;
        end else begin
            if (slot_count == SLOT_CYCLES-1) begin slot_count <= 0; index <= index + 1'b1; end
            else slot_count <= slot_count + 1'b1;
            if (slot_count == 0) begin
                seg_cs_pin <= 0;
                if (index == 0) begin
                    frame_valid <= measurement_valid;
                    frame_digits <= measurement_valid ? bcd : 32'hffffffff;
                end
            end
            if (slot_count == 1) begin
                seg_data_0_pin <= index < 4 ? segments : 0;
                seg_data_1_pin <= index >= 4 ? segments : 0;
            end
            if (slot_count == 2) seg_cs_pin <= 8'b1 << index;
        end
    end
endmodule
