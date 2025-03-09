////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: PWM Generator
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    Generate PWM waveform according to the speed parameter
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    Generate PWM waveform according to the speed parameter
////////////////////////////////////////////////////////////////////////////////
module pwm_output(
    input clk,
    input rstn,
    input [11:0] speed,
    output pwm
);

reg [5:0] cnt_20;
wire clk_2_5MHz; // 2.5MHz
always@(posedge clk or negedge rstn)begin
    if(~rstn)
        cnt_20 <= 1'b0;
    else if(cnt_20 == 19)
        cnt_20 <= 1'b0;
    else 
        cnt_20 <= cnt_20 + 1'b1;
end

assign clk_2_5MHz = (cnt_20 == 19)?1:0;

reg [9:0] cnt_100;
always@(posedge clk_2_5MHz or negedge rstn)begin
    if(~rstn)
        cnt_100 <= 1'b0;
    else if(cnt_100 == 99)
        cnt_100 <= 1'b0;
    else
        cnt_100 <= cnt_100 + 1'b1;
end

assign pwm = (speed >= cnt_100);

endmodule