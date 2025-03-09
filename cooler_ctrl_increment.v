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
//    
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    Self Adaptive Mode (Incermental Mode)
////////////////////////////////////////////////////////////////////////////////

module cooler_ctrl_increment(
    input clk,
    input rstn,
    input [11:0] temp,
    output reg [11:0] speed
);

parameter S0_INIT = 0;
parameter S1_WARMER = 1;
parameter S2_STABLE = 2;
parameter S3_COLDER = 3;

parameter signed TEMP_THRESHOLD = 4;

parameter CNT_MAX = 5000000; /* f=50MHz(T=20ns) => T'=0.1s */
//parameter CNT_MAX = 5; /* 5*20ns = 100ns , Test usage*/


// Divider
reg [19:0] cnt_01;
wire clk_01s;

// FSM vals
reg [1:0] state;
reg [1:0] next_state;

// temp record
reg [11:0] start_temp;
reg [11:0] now_temp;
wire signed [11:0] inc;

assign inc = now_temp - start_temp;

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
            if(inc == 0)
                next_state = S0_INIT;
            else if(inc > 0)
                next_state = S1_WARMER;
            else
                next_state = S3_COLDER;
        end
        S1_WARMER: begin
            if(inc == 0 || inc >= TEMP_THRESHOLD)
                next_state = S1_WARMER;
            else if(inc < 0)
                next_state = S3_COLDER;
            else
                next_state = S2_STABLE;
        end
        S2_STABLE: begin
            if(inc > -TEMP_THRESHOLD && inc < TEMP_THRESHOLD)
                next_state = S2_STABLE;
            else if(inc >= TEMP_THRESHOLD)
                next_state = S1_WARMER;
            else 
                next_state = S3_COLDER;
        end
        S3_COLDER: begin
            if(inc == 0 || inc <= -TEMP_THRESHOLD)
                next_state = S3_COLDER;
            else if(inc > 0)
                next_state = S1_WARMER;
            else
                next_state = S2_STABLE;
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
        start_temp <= 0;
    end
    else begin
        case(state)
            S0_INIT: begin
                speed <= 0;
            end
            S1_WARMER: begin
                if(inc >= TEMP_THRESHOLD) begin
                    speed <= speed + 1'b1;
                    start_temp <= temp;
                end
            end
            S2_STABLE: begin
                speed <= speed;
                start_temp <= start_temp;
            end 
            S3_COLDER: begin
                if(inc <= -TEMP_THRESHOLD) begin
                    speed <= speed - 1'b1;
                    start_temp <= temp;
                end
            end 
            default: speed <= 0; 
        endcase
    end
end

endmodule