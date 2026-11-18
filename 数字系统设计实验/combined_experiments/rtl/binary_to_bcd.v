`timescale 1ns / 1ps
module binary_to_bcd(input wire clk,input wire rst_n,input wire [31:0] value,output reg [31:0] bcd);
    reg [31:0] binary_work,bcd_work;
    reg [5:0] remaining;
    reg [31:0] adjusted;
    integer i;
    always @*begin
        adjusted=bcd_work;
        for(i=0;i<8;i=i+1)if(bcd_work[4*i+:4]>=5)adjusted[4*i+:4]=bcd_work[4*i+:4]+4'd3;
    end
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin binary_work<=0;bcd_work<=0;remaining<=0;bcd<=0;end
        else if(remaining==0)begin binary_work<=value;bcd_work<=0;remaining<=32;end
        else begin
            binary_work<={binary_work[30:0],1'b0};bcd_work<={adjusted[30:0],binary_work[31]};remaining<=remaining-1'b1;
            if(remaining==1)bcd<={adjusted[30:0],binary_work[31]};
        end
    end
endmodule
