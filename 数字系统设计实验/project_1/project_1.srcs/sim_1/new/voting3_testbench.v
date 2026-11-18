`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/19 16:41:10
// Design Name: 
// Module Name: voting3_testbench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module voting3_testbench(

    );
    reg x , y , z ;
    wire f ;
    
    voting3 t0(
    .a(x),
    .b(y),
    .c(z),
    .f(f)
    );
    
    initial 
    begin 
        x =0 ; y=0 ; z=0 ;
        repeat(8)
        #10 {x,y,z}={x,y,z}+1;
    end
    
endmodule
