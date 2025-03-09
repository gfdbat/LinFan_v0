////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: Fan RPM Counter
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    Count the TACH signal to get RPM
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    Fan RPM counter
////////////////////////////////////////////////////////////////////////////////
module fan_rpm_counter (
    input wire clk,       
    input wire rstn,      
    input wire tach,      
    output reg [15:0] rpm 
);

    reg [31:0] clk_count;      
    reg [15:0] pulse_count;    
    reg tach_d;                

    // 下降沿检测
    always @(posedge clk) begin
        tach_d <= tach;  // 采样信号用于比较
    end

    wire tach_falling = tach_d & ~tach;  // 检测下降沿

    // 主测速逻辑
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            clk_count   <= 0;
            pulse_count <= 0;
            rpm         <= 0;
        end else begin
            clk_count <= clk_count + 1;

            // 下降沿触发脉冲计数
            if (tach_falling) begin
                pulse_count <= pulse_count + 1;
            end

            // 每 50_000_000 次时钟（1 秒）计算 RPM
            if (clk_count >= 50_000_000) begin
                clk_count <= 0;
                rpm <= (pulse_count * 30); // RPM 计算公式（假设 2 个脉冲 1 转）
                pulse_count <= 0;
            end
        end
    end

endmodule