`timescale 1ns / 1ps
module translation_fir (
    input wire clk, input wire rst_n, input wire input_valid,
    input wire signed [15:0] sample_in,
    output reg output_valid, output reg signed [15:0] sample_out,
    output reg overrun
);
    localparam integer TAPS = 81;
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
                7'd1: coefficient = -16'sd6;
                7'd2: coefficient = 16'sd3;
                7'd3: coefficient = 16'sd10;
                7'd4: coefficient = -16'sd9;
                7'd5: coefficient = -16'sd14;
                7'd6: coefficient = 16'sd21;
                7'd7: coefficient = 16'sd14;
                7'd8: coefficient = -16'sd37;
                7'd9: coefficient = -16'sd7;
                7'd10: coefficient = 16'sd57;
                7'd11: coefficient = -16'sd11;
                7'd12: coefficient = -16'sd76;
                7'd13: coefficient = 16'sd43;
                7'd14: coefficient = 16'sd89;
                7'd15: coefficient = -16'sd90;
                7'd16: coefficient = -16'sd87;
                7'd17: coefficient = 16'sd151;
                7'd18: coefficient = 16'sd60;
                7'd19: coefficient = -16'sd219;
                7'd20: coefficient = 16'sd0;
                7'd21: coefficient = 16'sd282;
                7'd22: coefficient = -16'sd100;
                7'd23: coefficient = -16'sd326;
                7'd24: coefficient = 16'sd243;
                7'd25: coefficient = 16'sd330;
                7'd26: coefficient = -16'sd427;
                7'd27: coefficient = -16'sd271;
                7'd28: coefficient = 16'sd643;
                7'd29: coefficient = 16'sd120;
                7'd30: coefficient = -16'sd877;
                7'd31: coefficient = 16'sd158;
                7'd32: coefficient = 16'sd1110;
                7'd33: coefficient = -16'sd622;
                7'd34: coefficient = -16'sd1322;
                7'd35: coefficient = 16'sd1413;
                7'd36: coefficient = 16'sd1491;
                7'd37: coefficient = -16'sd3051;
                7'd38: coefficient = -16'sd1601;
                7'd39: coefficient = 16'sd10285;
                7'd40: coefficient = 16'sd18028;
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
