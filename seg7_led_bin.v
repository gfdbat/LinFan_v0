////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: 7segments Digital Tube Driver(input with BIN code)
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    7segments Digital Tube Driver(input with BCD code)
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    7segments Digital Tube Driver(input with BIN code)
////////////////////////////////////////////////////////////////////////////////
`include "bin_2_bcd.v"
`include "seg7_led_bcd.v"
module seg7_led_bin
#(
    parameter BIN_WIDTH = 32
)
(
    input clk,
    input rstn,
    input [BIN_WIDTH-1:0] bin_i,
    output [3:0]    sel,
    output [7:0]    seg_led    
);

wire [15:0] num_led_bcd;

bin_2_bcd #(
    .W(BIN_WIDTH)
)u_bin_bcd(
    .bin(bin_i),
    .bcd(num_led_bcd)
);

seg7_led_bcd u_seg7(
    .clk(clk),
    .rstn(rstn),
    .bcd(num_led_bcd),
    .sel_t(sel),
    .seg_led_t(seg_led)
);

endmodule