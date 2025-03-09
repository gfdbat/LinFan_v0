////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: XADC Temperature Reader
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    Read the temperature
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    Read the temperature
//    AMD Xilinx XADC IP should be included
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module xadc_ctrl(
    input clk,
    input rstn,
    output reg [11:0] temp
);

reg [15:0] di_in;
reg [6:0] daddr_in;
reg den_in;
wire [15:0] do_out;
wire drdy_out;
wire eoc_out;
wire [4:0] channel_out;


// initial read
always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
        daddr_in <= 7'b0;
        den_in <= 1'b0;
    end else if(eoc_out) begin
        daddr_in <= {2'b00, channel_out};
        den_in <= 1'b1;
    end else begin
        daddr_in <= 7'b0;
        den_in <= 1'b0;
    end
end

// Read output
always@(posedge clk or negedge rstn)begin
    if(~rstn)begin
        temp <= 12'b0;
    end
    else if(drdy_out) begin
        case(channel_out)
            5'h00: temp <= do_out[15:4];
            default: temp <= temp;
        endcase
    end
end

xadc_ec inst_xadc_ec (
  .dclk_in(clk),          // input wire dclk_in
  .reset_in(~rstn),        // input wire reset_in
  .di_in(16'b0),              // input wire [15 : 0] di_in
  .daddr_in(daddr_in),        // input wire [6 : 0] daddr_in
  .den_in(den_in),            // input wire den_in
  .dwe_in(0),            // input wire dwe_in   // read-only
  .drdy_out(drdy_out),        // output wire drdy_out
  .do_out(do_out),            // output wire [15 : 0] do_out
  .vp_in(1'b0),              // input wire vp_in
  .vn_in(1'b0),              // input wire vn_in
  .channel_out(channel_out),  // output wire [4 : 0] channel_out
  .eoc_out(eoc_out),          // output wire eoc_out
  .alarm_out(),      // output wire alarm_out
  .eos_out(),          // output wire eos_out
  .busy_out()        // output wire busy_out
);

endmodule