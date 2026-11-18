`timescale 1ns / 1ps

// Experiment 1: 100 MHz -> 10 MHz and 1 kHz, both 50% duty cycle.
module clock_divider_top (
    input wire clk_in,
    input wire rst,
    output reg clk_10mhz,
    output reg clk_1khz
);
    // S0/R11 is active high. Assert immediately and release on the system clock.
    // INIT also holds the design in reset for two clocks after FPGA startup.
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_release = 2'b11;
    always @(posedge clk_in or posedge rst) begin
        if (rst)
            reset_release <= 2'b11;
        else
            reset_release <= {reset_release[0], 1'b0};
    end
    wire reset_active = reset_release[1];

    reg [2:0] count_10mhz;
    reg [15:0] count_1khz;
    always @(posedge clk_in or posedge reset_active) begin
        if (reset_active) begin
            count_10mhz <= 3'd0;
            count_1khz <= 16'd0;
            clk_10mhz <= 1'b0;
            clk_1khz <= 1'b0;
        end else begin
            // Toggle every 5 clocks: full period = 10 * 10 ns = 100 ns.
            if (count_10mhz == 3'd4) begin
                count_10mhz <= 3'd0;
                clk_10mhz <= ~clk_10mhz;
            end else
                count_10mhz <= count_10mhz + 1'b1;

            // Toggle every 50,000 clocks: full period = 100,000 * 10 ns = 1 ms.
            if (count_1khz == 16'd49999) begin
                count_1khz <= 16'd0;
                clk_1khz <= ~clk_1khz;
            end else
                count_1khz <= count_1khz + 1'b1;
        end
    end
endmodule
