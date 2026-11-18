`timescale 1ns / 1ps
module decimate_by_five (
    input wire clk, input wire rst_n, input wire input_valid,
    input wire signed [15:0] sample_in,
    output reg output_valid, output reg signed [15:0] sample_out
);
    // Three cascaded five-sample moving sums before 5:1 decimation.
    // DC gain 125 is normalized by 128, retaining 0.9765625 gain.
    reg signed [15:0] delay1 [0:4];
    reg signed [18:0] delay2 [0:4];
    reg signed [21:0] delay3 [0:4];
    reg signed [18:0] sum1;
    reg signed [21:0] sum2;
    reg signed [24:0] sum3;
    wire signed [24:0] next_sum3 = sum3 + sum2 - delay3[4];
    reg [2:0] count;
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum1 <= 0; sum2 <= 0; sum3 <= 0; count <= 0;
            output_valid <= 0; sample_out <= 0;
            for (i = 0; i < 5; i = i + 1) begin delay1[i] <= 0; delay2[i] <= 0; delay3[i] <= 0; end
        end else begin
            output_valid <= 0;
            if (input_valid) begin
                sum1 <= sum1 + sample_in - delay1[4];
                sum2 <= sum2 + sum1 - delay2[4];
                sum3 <= next_sum3;
                delay1[0] <= sample_in; delay2[0] <= sum1; delay3[0] <= sum2;
                for (i = 1; i < 5; i = i + 1) begin
                    delay1[i] <= delay1[i-1]; delay2[i] <= delay2[i-1]; delay3[i] <= delay3[i-1];
                end
                if (count == 4) begin
                    count <= 0; sample_out <= (next_sum3 + 25'sd64) >>> 7; output_valid <= 1;
                end else count <= count + 1'b1;
            end
        end
    end
endmodule
