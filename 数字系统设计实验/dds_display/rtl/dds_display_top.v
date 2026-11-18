`timescale 1ns / 1ps

module dds_display_top #(
    parameter integer SCAN_SLOT_CYCLES = 50000
) (
    input wire clk_in,
    input wire sys_rst_n,
    input wire [7:0] sw,
    input wire [1:0] dip,
    output wire [7:0] seg_cs_pin,
    output wire [7:0] seg_data_0_pin,
    output wire [7:0] seg_data_1_pin,
    output wire clk_da,
    output wire [7:0] sin_out
);
    // Asynchronous assertion, synchronous release of the active-low reset.
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync;
    always @(posedge clk_in or negedge sys_rst_n)
        if (!sys_rst_n) reset_sync <= 2'b00;
        else reset_sync <= {reset_sync[0], 1'b1};
    wire rst_n = reset_sync[1];

    // Two stages reduce metastability risk for manual switches. Multiple bits
    // can settle at different times; set the switches before measurement.
    (* ASYNC_REG = "TRUE" *) reg [7:0] sw_meta, sw_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] dip_meta, dip_sync;
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            sw_meta <= 0;
            sw_sync <= 0;
            dip_meta <= 0;
            dip_sync <= 0;
        end else begin
            sw_meta <= sw;
            sw_sync <= sw_meta;
            dip_meta <= dip;
            dip_sync <= dip_meta;
        end
    end

    wire [31:0] frequency_bcd;
    frequency_display_value u_frequency (
        .clk(clk_in), .rst_n(rst_n), .tuning_word(sw_sync), .bcd(frequency_bcd)
    );
    seven_segment_scan #(.SLOT_CYCLES(SCAN_SLOT_CYCLES)) u_display (
        .clk(clk_in), .rst_n(rst_n), .mode(dip_sync),
        .frequency_bcd(frequency_bcd), .seg_cs_pin(seg_cs_pin),
        .seg_data_0_pin(seg_data_0_pin), .seg_data_1_pin(seg_data_1_pin)
    );
    // Waveform output runs in every display mode, including the blank modes.
    dds_sine u_dds (
        .clk(clk_in), .rst_n(rst_n), .tuning_word(sw_sync),
        .clk_da(clk_da), .sin_out(sin_out)
    );
endmodule
