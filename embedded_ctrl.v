////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: Embedded Controller(Top Module)
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    Heat Controller 
// Dependencies:
//    <As shown below>
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    Top Module
////////////////////////////////////////////////////////////////////////////////
`include "xadc_ctrl.v"
`include "cooler_ctrl_increment.v"
`include "seg7_led_bin.v"
`include "oled_ctrl.v"
`include "pwm_output.v"
`include "fan_rpm_counter.v"
`include "cooler_ctrl_tempTarget.v"

module embedded_ctrl (
    input clk,
    input rstn,

    input rpm_speed,

    output pwm,

    output [3:0]    sel,
    output [7:0]    seg_led,
    output              iic_scl,  
    inout               iic_sda    
);


wire [11:0] raw_temp;
wire [11:0] temp; /* 20'C - 100'C.  200.1C - 1000.1C */
wire [15:0] rpm;
wire [11:0] speed;

// Convert temperature from raw data to numeric data in the unit of 0.1'
assign temp = raw_temp + (raw_temp >> 3) + (raw_temp >> 4) + (raw_temp >> 5) - 2701;

// Temperature Read
xadc_ctrl inst_xadc_c(
    .clk(clk),
    .rstn(rstn),
    .temp(raw_temp)
);

// Cooler Controller
cooler_ctrl_tempTarget inst_cooler_c(
    .clk(clk),
    .rstn(rstn),
    .temp_target(400), // Set the Target Temperature. !!(Unit: 0.1'C)!!
    .temp(temp),
    .speed(speed)
);

// PWM Output
pwm_output u_pwm_output(
  .clk(clk),
  .rstn(rstn),
  .speed(speed),
  .pwm(pwm)
);

// Fan RPM Counter 
fan_rpm_counter u_rpm_cnt(
  .clk(clk),
  .rstn(rstn),
  .tach(rpm_speed),
  .rpm(rpm)
);

// Early Debugging Use: 7-Segments Digital Tube
seg7_led_bin #(
  .BIN_WIDTH(12)
) inst_seg7(
  .clk(clk),
  .rstn(rstn),
  .bin_i(rpm), // temp or rpm
  .sel(sel),
  .seg_led(seg_led)
);

// OLED Controller
oled_ctrl u_oled_ctrl(
  .clk(clk),
  .rstn(rstn),
  .temp(temp),
  .ctrl_speed(speed),
  .rpm(rpm),
  .iic_scl(iic_scl),  
  .iic_sda(iic_sda)    
);

endmodule
