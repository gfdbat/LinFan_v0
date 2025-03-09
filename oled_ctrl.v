////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: OLED Display Controller 
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    OLED Display Controller Top Module
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    OLED Display Controller Top Module
////////////////////////////////////////////////////////////////////////////////

`include "oled_data_gen.v"
`include "i2c_dri.v"
`include "bin_2_bcd.v"
module oled_ctrl(
    input clk,
    input rstn,
    input [11:0] temp,
    input [11:0] ctrl_speed,
    input [15:0] rpm,

    output iic_scl, 
    inout iic_sda    
);


wire           dri_clk   ; 
wire           i2c_exec  ; 
wire   [15:0]  i2c_addr  ; 
wire   [ 7:0]  i2c_data_w; 
wire           i2c_done  ; 
wire           i2c_ack   ; 
wire           i2c_rh_wl ; 
wire   [ 7:0]  i2c_data_r; 


oled_data_gen u_oled(
    .clk         (dri_clk   ),  
    .rstn       (rstn ),  

    .temp(temp),
    .ctrl_speed(ctrl_speed),
    .rpm(rpm),

    //i2c interface
    .i2c_exec    (i2c_exec  ), 
    .i2c_rh_wl   (i2c_rh_wl ), 
    .i2c_addr    (i2c_addr  ), 
    .i2c_data_w  (i2c_data_w), 
    .i2c_data_r  (i2c_data_r), 
    .i2c_done    (i2c_done  ), 
    .i2c_ack     (i2c_ack   )  
);

i2c_dri u_i2c_dri(
    .clk         (clk   ),  
    .rst_n       (rstn ),  
    //i2c interface
    .i2c_exec    (i2c_exec  ), 
    .bit_ctrl    (1'b0),  
    .i2c_rh_wl   (i2c_rh_wl ), 
    .i2c_addr    (i2c_addr  ), 
    .i2c_data_w  (i2c_data_w), 
    .i2c_data_r  (i2c_data_r), 
    .i2c_done    (i2c_done  ), 
    .i2c_ack     (i2c_ack   ), 
    .scl         (iic_scl   ), 
    .sda         (iic_sda   ), 
    //user interface
    .dri_clk     (dri_clk   )  
);

endmodule