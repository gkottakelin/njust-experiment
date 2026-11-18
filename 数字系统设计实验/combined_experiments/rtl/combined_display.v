`timescale 1ns / 1ps
module combined_display #(parameter integer SLOT_CYCLES=100000)(
    input wire clk,input wire rst_n,input wire [7:0] active_mode,
    input wire [31:0] dds_bcd,input wire [31:0] measured_bcd,input wire measurement_valid,
    output reg [7:0] seg_cs_pin,output reg [7:0] seg_data_0_pin,output reg [7:0] seg_data_1_pin
);
    reg [31:0] slot_count,frame_digits;
    reg [2:0] index;
    reg [7:0] frame_dp;
    reg frame_enabled;
    wire [3:0] character=(frame_digits>>((7-index)*4))&4'hf;
    wire [7:0] segments={frame_dp[index],decode(character)};
    function [6:0] decode;
        input [3:0] c;
        begin case(c)
            0:decode=7'h3f;1:decode=7'h06;2:decode=7'h5b;3:decode=7'h4f;4:decode=7'h66;
            5:decode=7'h6d;6:decode=7'h7d;7:decode=7'h07;8:decode=7'h7f;9:decode=7'h6f;
            10:decode=7'h08;default:decode=7'h40;
        endcase end
    endfunction
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            slot_count<=0;index<=0;frame_digits<=32'h12345678;frame_dp<=8'h00;frame_enabled<=1;
            seg_cs_pin<=0;seg_data_0_pin<=0;seg_data_1_pin<=0;
        end else begin
            if(slot_count==SLOT_CYCLES-1)begin slot_count<=0;index<=index+1'b1;end
            else slot_count<=slot_count+1'b1;
            if(slot_count==0)begin
                seg_cs_pin<=0;
                if(index==0)begin
                    frame_enabled<=1;
                    case(active_mode)
                        8'h00:begin frame_digits<=32'h12345678;frame_dp<=8'h00;end
                        8'h02:begin frame_digits<=32'h2610a652;frame_dp<=8'h02;end
                        8'h04:begin frame_digits<=dds_bcd;frame_dp<=8'h10;end
                        8'h08,8'h10,8'h11:begin
                            frame_digits<=measurement_valid?measured_bcd:32'hffffffff;
                            frame_dp<=measurement_valid?8'h10:8'h00;
                        end
                        default:begin frame_enabled<=0;frame_digits<=0;frame_dp<=0;end
                    endcase
                end
            end
            if(slot_count==1)begin seg_data_0_pin<=index<4?segments:0;seg_data_1_pin<=index>=4?segments:0;end
            if(slot_count==2)seg_cs_pin<=frame_enabled?(8'b1<<index):0;
        end
    end
endmodule
