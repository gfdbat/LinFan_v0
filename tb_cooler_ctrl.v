////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: testbench of cooler_ctrl
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    testbench
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    testbench of cooler_ctrl
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`include "cooler_ctrl_increment.v"
module tb_cooler_ctrl();
reg clk;
reg rstn;
reg [9:0] temp;
wire [9:0] speed;

initial begin
    clk = 1'b0;
    rstn = 1'b0;
    #40
    rstn = 1'b1;
end

integer i;
initial begin
    temp = 0;
    #40
//    temp = 1;
//    #100
//    temp = 2;
//    #100
//    temp = 3;
//    #100
//    temp = 4;
//    #100
//    temp = 5;
//    #100
//    temp = 6;
//    #100
//    temp = 7;
//    #100
//    temp = 8;
//    #100
//    temp = 9;
//    #100
//    temp = 10;
//    #100
//    temp = 11;
//    #100
//    temp = 10;
//    #100
//    temp = 9;
//    #100
//    temp = 8;
//    #100
//    temp = 7;
//    #100
//    temp = 6;
//    #100
//    temp = 5;
//    #100
//    temp = 4;
//    #100
//    temp = 5;
//    #100
//    temp = 4;
//    #100
//    temp = 5;
//    #100
//    temp = 5;
//    #100
//    temp = 4;
//    #100
//    temp = 5;
    for (i = 0; i < 50; i = i + 1) begin
        #100
        temp = temp + 1;
        
    end
    for (i = 0; i < 50; i = i + 1) begin
        #100
        temp = temp + (temp%2?1:(-1));
    end
    
    for (i = 0; i < 30; i = i + 1) begin
        #100
        temp = temp -1;
    end
end

always #10 clk = ~clk;

cooler_ctrl_increment u_cc(
    .clk(clk),
    .rstn(rstn),
    .temp(temp),
    .speed(speed)
);
endmodule