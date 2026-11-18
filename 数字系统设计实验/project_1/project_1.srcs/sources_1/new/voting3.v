`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/10/19 16:32:30
// Design Name: 
// Module Name: voting3
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


module voting3(
    input a ,
    input b ,
    input c ,
    output f
    );
    
    assign f = a&b | a&c | b&c ;
endmodule
