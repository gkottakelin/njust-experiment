`timescale 1ns / 1ps
module tb_interpolation;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,input_valid=0;
    reg signed [15:0] level=0,sample=0;
    wire output_valid,error;
    wire signed [15:0] result;
    interpolate_by_five dut(.clk(clk),.rst_n(rst_n),.input_valid(input_valid),
        .sample_in(sample),.output_valid(output_valid),.sample_out(result),.cadence_error(error));
    integer count=49,cycles=0,last_output=-1,checked=0;
    reg checking=0;
    always @(posedge clk) cycles<=cycles+1;
    always @(negedge clk) begin
        if(!rst_n)begin count=49;input_valid=0;sample=0;end
        else begin
            count=count==49?0:count+1;input_valid=count==0;sample=level;
        end
    end
    always @(posedge output_valid) begin
        #1;
        if(last_output>=0 && cycles-last_output!=10)$fatal(1,"Interpolator output cadence is not 10 MHz");
        last_output=cycles;
        if(checking)begin
            if(result!==level)$fatal(1,"Polyphase DC gain/sign error: expected %0d actual %0d",level,result);
            checked=checked+1;
        end
        if(error)$fatal(1,"Input/output cadence mismatch");
    end
    task automatic check_dc(input signed [15:0] value);
        begin
            checking=0;level=value;repeat(1000)@(negedge clk);
            checking=1;repeat(1000)@(negedge clk);checking=0;
        end
    endtask
    initial begin
        #35;rst_n=1;
        check_dc(0);check_dc(1600);check_dc(-1600);check_dc(30000);check_dc(-30000);
        if(checked<450)$fatal(1,"Too few phase checks");
        $display("PASS: interpolation 10 MHz output cadence and all five phases preserve positive/negative DC including full-range values");
        $finish;
    end
    initial begin #200000;$fatal(1,"Interpolation unit timeout");end
endmodule
