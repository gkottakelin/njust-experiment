`timescale 1ns / 1ps
module sample_clocking (
    input wire clk, input wire rst_n, input wire [9:0] ad_in,
    output reg converter_clk, output reg [9:0] adc_sample,
    output reg adc_valid, output wire dac_update
);
    reg [3:0] phase;
    assign dac_update = (phase == 0);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 0; converter_clk <= 0; adc_sample <= 512; adc_valid <= 0;
        end else begin
            phase <= phase == 9 ? 4'd0 : phase + 1'b1;
            adc_valid <= 0;
            if (phase == 0) converter_clk <= 0;
            if (phase == 5) converter_clk <= 1;
            // 40 ns after converter falling edge; MS9280 specifies 25 ns tOD.
            if (phase == 4) begin adc_sample <= ad_in; adc_valid <= 1; end
        end
    end
endmodule
