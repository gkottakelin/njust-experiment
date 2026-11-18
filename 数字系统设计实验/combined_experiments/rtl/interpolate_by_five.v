`timescale 1ns / 1ps
module interpolate_by_five (
    input wire clk, input wire rst_n, input wire input_valid,
    input wire signed [15:0] sample_in,
    output reg output_valid, output reg signed [15:0] sample_out,
    output reg cadence_error
);
    // Input/output samples are Q4 ADC-code units. 61 taps, 5 polyphases,
    // 13 parallel DSP products. Output is a new sample every 10 system clocks.
    reg signed [15:0] history [0:12];
    reg active;
    reg [3:0] tick;
    reg [2:0] phase;
    reg [5:0] input_age;
    wire launch = active && tick == 0 && !input_valid;
    reg [4:0] valid_pipe;
    reg signed [33:0] products [0:12];
    reg signed [34:0] sum1 [0:6];
    reg signed [35:0] sum2 [0:3];
    reg signed [36:0] sum3 [0:1];
    reg signed [37:0] sum4;
    wire signed [37:0] rounded = (sum4 + 38'sd32768) >>> 16;
    integer i;
    function signed [17:0] coefficient;
        input [6:0] index;
        begin
            case(index)
                7'd0: coefficient = 18'sd0;
                7'd1: coefficient = -18'sd7;
                7'd2: coefficient = -18'sd25;
                7'd3: coefficient = -18'sd45;
                7'd4: coefficient = -18'sd46;
                7'd5: coefficient = 18'sd0;
                7'd6: coefficient = 18'sd107;
                7'd7: coefficient = 18'sd250;
                7'd8: coefficient = 18'sd351;
                7'd9: coefficient = 18'sd298;
                7'd10: coefficient = 18'sd0;
                7'd11: coefficient = -18'sd527;
                7'd12: coefficient = -18'sd1108;
                7'd13: coefficient = -18'sd1419;
                7'd14: coefficient = -18'sd1111;
                7'd15: coefficient = 18'sd0;
                7'd16: coefficient = 18'sd1727;
                7'd17: coefficient = 18'sd3444;
                7'd18: coefficient = 18'sd4218;
                7'd19: coefficient = 18'sd3178;
                7'd20: coefficient = 18'sd0;
                7'd21: coefficient = -18'sd4697;
                7'd22: coefficient = -18'sd9257;
                7'd23: coefficient = -18'sd11340;
                7'd24: coefficient = -18'sd8679;
                7'd25: coefficient = 18'sd0;
                7'd26: coefficient = 18'sd14260;
                7'd27: coefficient = 18'sd31753;
                7'd28: coefficient = 18'sd48714;
                7'd29: coefficient = 18'sd61033;
                7'd30: coefficient = 18'sd65536;
                7'd31: coefficient = 18'sd61033;
                7'd32: coefficient = 18'sd48714;
                7'd33: coefficient = 18'sd31753;
                7'd34: coefficient = 18'sd14260;
                7'd35: coefficient = 18'sd0;
                7'd36: coefficient = -18'sd8679;
                7'd37: coefficient = -18'sd11340;
                7'd38: coefficient = -18'sd9257;
                7'd39: coefficient = -18'sd4697;
                7'd40: coefficient = 18'sd0;
                7'd41: coefficient = 18'sd3178;
                7'd42: coefficient = 18'sd4218;
                7'd43: coefficient = 18'sd3444;
                7'd44: coefficient = 18'sd1727;
                7'd45: coefficient = 18'sd0;
                7'd46: coefficient = -18'sd1111;
                7'd47: coefficient = -18'sd1419;
                7'd48: coefficient = -18'sd1108;
                7'd49: coefficient = -18'sd527;
                7'd50: coefficient = 18'sd0;
                7'd51: coefficient = 18'sd298;
                7'd52: coefficient = 18'sd351;
                7'd53: coefficient = 18'sd250;
                7'd54: coefficient = 18'sd107;
                7'd55: coefficient = 18'sd0;
                7'd56: coefficient = -18'sd46;
                7'd57: coefficient = -18'sd45;
                7'd58: coefficient = -18'sd25;
                7'd59: coefficient = -18'sd7;
                7'd60: coefficient = 18'sd0;
                default: coefficient = 0;
            endcase
        end
    endfunction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 0; tick <= 0; phase <= 0; input_age <= 0;
            valid_pipe <= 0; output_valid <= 0; sample_out <= 0;
            cadence_error <= 0; sum4 <= 0;
            for(i=0;i<13;i=i+1) begin history[i] <= 0; products[i] <= 0; end
            for(i=0;i<7;i=i+1) sum1[i] <= 0;
            for(i=0;i<4;i=i+1) sum2[i] <= 0;
            for(i=0;i<2;i=i+1) sum3[i] <= 0;
        end else begin
            valid_pipe <= {valid_pipe[3:0],launch};
            output_valid <= valid_pipe[4];
            if(input_valid) begin
                if(active && input_age != 49) cadence_error <= 1;
                input_age <= 0; active <= 1; tick <= 0; phase <= 0;
                for(i=12;i>0;i=i-1) history[i] <= history[i-1];
                history[0] <= sample_in;
            end else if(active) begin
                if(input_age != 63) input_age <= input_age + 1'b1;
                if(tick == 9) begin
                    tick <= 0; phase <= phase == 4 ? 0 : phase + 1'b1;
                end else tick <= tick + 1'b1;
            end
            if(launch) for(i=0;i<13;i=i+1)
                products[i] <= history[i] * coefficient(phase+5*i);
            if(valid_pipe[0]) begin
                for(i=0;i<6;i=i+1) sum1[i] <= $signed(products[2*i]) + $signed(products[2*i+1]);
                sum1[6] <= products[12];
            end
            if(valid_pipe[1]) begin
                for(i=0;i<3;i=i+1) sum2[i] <= $signed(sum1[2*i]) + $signed(sum1[2*i+1]);
                sum2[3] <= sum1[6];
            end
            if(valid_pipe[2]) begin
                sum3[0] <= $signed(sum2[0]) + $signed(sum2[1]);
                sum3[1] <= $signed(sum2[2]) + $signed(sum2[3]);
            end
            if(valid_pipe[3]) sum4 <= $signed(sum3[0]) + $signed(sum3[1]);
            if(valid_pipe[4]) begin
                if(rounded > 38'sd32767) sample_out <= 16'sh7fff;
                else if(rounded < -38'sd32768) sample_out <= 16'sh8000;
                else sample_out <= rounded[15:0];
            end
        end
    end
endmodule
