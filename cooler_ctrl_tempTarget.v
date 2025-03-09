////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 11:45
// Design Name: Linfan0
// Module Name: Cooler Controller
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    Controller for 4-Pin PWM Cooler 
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    Temperature Targetted Mode
////////////////////////////////////////////////////////////////////////////////

module cooler_ctrl_tempTarget (
    input clk,
    input rstn,
    input signed [11:0] temp_target,
    input [11:0] temp,
    output reg [11:0] speed // 0 - 100
);

parameter S0_INIT = 0;
parameter S1_BEYOND = 1;
parameter S2_STABLE = 2;
parameter S3_LESS = 3;

parameter signed TEMP_THRESHOLD = 10; // 1'C

parameter CNT_MAX = 20000000; /* f=50MHz(T=20ns) => T'=0.1s(5000000) 0.6s*/
//parameter CNT_MAX = 5; /* 5*20ns = 100ns , Test usage*/


// Divider
reg [31:0] cnt_01;
wire clk_01s;

// FSM vals
reg [1:0] state;
reg [1:0] next_state;

// temp record
reg signed [11:0] now_temp;
wire signed [11:0] delta; 

assign delta = now_temp - temp_target; // if > 10(1'C), fan speed should +

// Divider
always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        cnt_01 <= 0;
    end else if(cnt_01 == CNT_MAX - 1) begin
        cnt_01 <= 0;
    end else begin
        cnt_01 <= cnt_01 + 1;
    end
end

assign clk_01s = (cnt_01 == CNT_MAX - 1);

// FSM(state driver)
always@(posedge clk_01s or negedge rstn)begin
    if(~rstn)
        state <= S0_INIT;
    else
        state <= next_state;
end

// FSM(next state logic)
always@(*)begin
    case(state)
        S0_INIT: begin
            if(delta > -TEMP_THRESHOLD && delta < TEMP_THRESHOLD)
                next_state = S2_STABLE;
            else if(delta >= TEMP_THRESHOLD)
                next_state = S1_BEYOND;
            else
                next_state = S3_LESS;
        end
        S1_BEYOND: begin
            if(delta > -TEMP_THRESHOLD && delta < TEMP_THRESHOLD)
                next_state = S2_STABLE;
            else if(delta >= TEMP_THRESHOLD)
                next_state = S1_BEYOND;
            else
                next_state = S3_LESS;
        end
        S2_STABLE: begin
            if(delta > -TEMP_THRESHOLD && delta < TEMP_THRESHOLD)
                next_state = S2_STABLE;
            else if(delta >= TEMP_THRESHOLD)
                next_state = S1_BEYOND;
            else 
                next_state = S3_LESS;
        end
        S3_LESS: begin
            if(delta > -TEMP_THRESHOLD && delta < TEMP_THRESHOLD)
                next_state = S2_STABLE;
            else if(delta >= TEMP_THRESHOLD)
                next_state = S1_BEYOND;
            else
                next_state = S3_LESS;
        end
        default: next_state = S0_INIT;
    endcase
end

// now temp
always@(posedge clk_01s or negedge rstn) begin
    if(~rstn) begin
        now_temp <= 0;
    end else begin
        now_temp <= temp;
    end
end

// speed ctrl and start temp loading
always@(posedge clk_01s or negedge rstn) begin
    if(~rstn) begin
        speed <= 0;
    end
    else begin
        case(state)
            S0_INIT: begin
                speed <= 0;
            end
            S1_BEYOND: begin
                if(speed < 99) begin
                    speed <= speed + 1'b1;
                end
            end
            S2_STABLE: begin
                speed <= speed;
            end 
            S3_LESS: begin
                if(speed > 0) begin
                    speed <= speed - 1'b1;
                end
            end 
            default: speed <= 0; 
        endcase
    end
end

endmodule