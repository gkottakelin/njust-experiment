`timescale 1ns / 1ps
module translation_fir (
    input wire clk, input wire rst_n, input wire input_valid,
    input wire signed [15:0] sample_in,
    output reg output_valid, output reg signed [15:0] sample_out,
    output reg overrun
);
    localparam integer TAPS = 41;
    localparam integer PRODUCTS = (TAPS+1)/2;
    reg signed [15:0] history [0:TAPS-1];
    reg busy;
    reg finish_pending;
    reg signed [39:0] finished_total;
    wire signed [39:0] scaled_finished = (finished_total + 40'sd8192) >>> 14;
    reg [6:0] feed_index, accumulated;
    reg read_valid, pair_valid, product_valid;
    reg signed [15:0] read_a, read_b, read_coefficient, pair_coefficient;
    reg signed [16:0] pair_value;
    reg signed [32:0] product;
    reg signed [39:0] accumulator;
    wire signed [39:0] total = accumulator + {{7{product[32]}}, product};
    integer i;
    function signed [15:0] coefficient;
        input [6:0] index;
        begin
            case (index)
                7'd0: coefficient = 16'sd0;
                7'd1: coefficient = -16'sd10;
                7'd2: coefficient = -16'sd29;
                7'd3: coefficient = -16'sd48;
                7'd4: coefficient = -16'sd46;
                7'd5: coefficient = 16'sd0;
                7'd6: coefficient = 16'sd94;
                7'd7: coefficient = 16'sd209;
                7'd8: coefficient = 16'sd280;
                7'd9: coefficient = 16'sd228;
                7'd10: coefficient = 16'sd0;
                7'd11: coefficient = -16'sd381;
                7'd12: coefficient = -16'sd787;
                7'd13: coefficient = -16'sd1004;
                7'd14: coefficient = -16'sd795;
                7'd15: coefficient = 16'sd0;
                7'd16: coefficient = 16'sd1372;
                7'd17: coefficient = 16'sd3108;
                7'd18: coefficient = 16'sd4826;
                7'd19: coefficient = 16'sd6089;
                7'd20: coefficient = 16'sd6556;
                default: coefficient = 0;
            endcase
        end
    endfunction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            finish_pending <= 0; finished_total <= 0;
            busy <= 0; feed_index <= 0; accumulated <= 0; accumulator <= 0;
            read_valid <= 0; pair_valid <= 0; product_valid <= 0;
            read_a <= 0; read_b <= 0; read_coefficient <= 0;
            pair_coefficient <= 0; pair_value <= 0; product <= 0;
            output_valid <= 0; sample_out <= 0; overrun <= 0;
            for (i = 0; i < TAPS; i = i+1) history[i] <= 0;
        end else begin
            output_valid <= 0; finish_pending <= 0;
            if(finish_pending) begin
                output_valid <= 1;
                if(scaled_finished > 40'sd32767) sample_out <= 16'sh7fff;
                else if(scaled_finished < -40'sd32768) sample_out <= 16'sh8000;
                else sample_out <= scaled_finished[15:0];
            end
            read_valid <= 0;
            pair_valid <= read_valid;
            product_valid <= pair_valid;
            if (input_valid) begin
                if (busy) overrun <= 1;
                else begin
                    for (i = TAPS-1; i > 0; i = i-1) history[i] <= history[i-1];
                    history[0] <= sample_in;
                    busy <= 1; feed_index <= 0; accumulated <= 0; accumulator <= 0;
                end
            end
            if (busy && feed_index < PRODUCTS) begin
                read_a <= history[feed_index];
                read_b <= feed_index == PRODUCTS-1 ? 16'sd0 : history[TAPS-1-feed_index];
                read_coefficient <= coefficient(feed_index);
                read_valid <= 1; feed_index <= feed_index + 1'b1;
            end
            if (read_valid) begin
                pair_value <= $signed({read_a[15],read_a}) + $signed({read_b[15],read_b});
                pair_coefficient <= read_coefficient;
            end
            if (pair_valid) product <= pair_value * pair_coefficient;
            if (product_valid) begin
                accumulator <= total; accumulated <= accumulated + 1'b1;
                if (accumulated == PRODUCTS-1) begin
                    // Q15 FIR scaling plus gain 2 compensates the real mixer.
                    finished_total <= total; finish_pending <= 1; busy <= 0;
                end
            end
        end
    end
endmodule
