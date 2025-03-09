////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: OLED Display Data Generator(Old version, NOT working)
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    Generate Wave and Characters for OLED to display
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    Generate Wave and Characters for OLED to display
////////////////////////////////////////////////////////////////////////////////
module oled_data_gen_vStatusStream(
    input clk,
    input rst_n,
    
    //i2c interface
    output   reg          i2c_rh_wl  , 
    output   reg          i2c_exec   , 
    output   reg  [15:0]  i2c_addr   , 
    output   reg  [ 7:0]  i2c_data_w , 
    input         [ 7:0]  i2c_data_r , 
    input                 i2c_done   , 
    input                 i2c_ack     
);

parameter      WR_WAIT_TIME = 14'd5000; // Write Pixel Interval(Wait for IIC operation to complete)

reg   [9:0]    flow_cnt  ; // Flow control
reg   [13:0]   wait_cnt  ; // Delay counter

reg [7:0] i2c_init_data [0:27];

reg init_done;

localparam INIT_STATUS = 0;
localparam CHAR_STATUS = 1;

reg [3:0] status;
reg [15:0] i2c_addr_init;
reg [7:0] i2c_data_w_init;
reg i2c_exec_init;
reg [15:0] i2c_addr_char;
reg [7:0] i2c_data_w_char;
reg i2c_exec_char;

always@(*)begin
    case(status)
        INIT_STATUS: begin
            i2c_addr <= i2c_addr_init;
            i2c_data_w <= i2c_data_w_init;
            i2c_exec <= i2c_exec_init;
        end
        CHAR_STATUS: begin
            i2c_addr <= i2c_addr_char;
            i2c_data_w <= i2c_data_w_char;
            i2c_exec <= i2c_exec_char;
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        i2c_exec_init   <= 1'b0;
        flow_cnt   <= 2'b0;
        i2c_rh_wl  <= 1'b0;
        i2c_addr_init   <= 16'b0;
        i2c_data_w_init <= 8'b0;
        wait_cnt   <= 14'b0;
        status <= 1'b0;
        i2c_init_data[0]  <= 8'hAE; i2c_init_data[1]  <= 8'h02;
        i2c_init_data[2]  <= 8'h10; i2c_init_data[3]  <= 8'h40;
        i2c_init_data[4]  <= 8'hB0; i2c_init_data[5]  <= 8'h81;
        i2c_init_data[6]  <= 8'hFF; i2c_init_data[7]  <= 8'hA1;
        i2c_init_data[8]  <= 8'hA6; i2c_init_data[9]  <= 8'hA8;
        i2c_init_data[10] <= 8'h3F; i2c_init_data[11] <= 8'hAD;
        i2c_init_data[12] <= 8'h8B; i2c_init_data[13] <= 8'h33;
        i2c_init_data[14] <= 8'hC8; i2c_init_data[15] <= 8'hD3;
        i2c_init_data[16] <= 8'h00; i2c_init_data[17] <= 8'hD5;
        i2c_init_data[18] <= 8'h80; i2c_init_data[19] <= 8'hD8;
        i2c_init_data[20] <= 8'h05; i2c_init_data[21] <= 8'hD9;
        i2c_init_data[22] <= 8'h1F; i2c_init_data[23] <= 8'hDA;
        i2c_init_data[24] <= 8'h12; i2c_init_data[25] <= 8'hDB;
        i2c_init_data[26] <= 8'h40; i2c_init_data[27] <= 8'hAF;
        init_done <= 1'b0;
    end
    else begin
        if(~init_done)begin
            i2c_exec_init <= 1'b0;
            if (flow_cnt < 28) begin
                wait_cnt <= wait_cnt + 1'b1;

                if (wait_cnt == WR_WAIT_TIME - 1) begin
                    i2c_exec_init   <= 1'b1;
                    wait_cnt   <= 14'b0;
                    i2c_addr_init   <= 8'h00; // write command
                    i2c_data_w_init <= i2c_init_data[flow_cnt]; // 取当前指令
                    flow_cnt   <= flow_cnt + 1'b1;
                end
            end else begin
                init_done <= 1'b1;
                status <= CHAR_STATUS;
            end
        end
    end
end    

parameter POS_SET_NUM = 3;
parameter CHAR_NUM = 28;
reg pos_set_done;
reg char_done;

reg [7:0] pos_data [2:0];
reg [7:0] char_data [5:0];
reg [6:0] x_pos;
reg [6:0] y_pos;

reg [9:0] char_flow_cnt;


always@(posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        char_done <= 1'b0;
        char_flow_cnt <= 1'b0;
        i2c_exec_char <= 1'b0;
        i2c_addr_char <= 16'b0;
        i2c_data_w_char <= 8'b0;
        x_pos <= 0;
        y_pos <= 0;
        char_data[0] <= 8'h00; char_data[1] <= 8'h24; char_data[2] <= 8'h2a; char_data[3] <= 8'h7f; char_data[4] <= 8'h2a; char_data[5] <= 8'h12; 
    end else if(~pos_set_done && init_done)begin
            i2c_exec_char <= 1'b0;
            
            pos_data[0] <= 8'hb0 + y_pos;
            pos_data[1] <= ((x_pos & 8'hf0) >> 4) | 8'h10;
            pos_data[2] <= (x_pos & 8'hf0) | 8'h10;

            if (char_flow_cnt < POS_SET_NUM) begin
                wait_cnt <= wait_cnt + 1'b1;
                if (wait_cnt == WR_WAIT_TIME - 1) begin
                    i2c_exec_char   <= 1'b1;
                    wait_cnt   <= 14'b0;
                    i2c_addr_char   <= 8'h00; // write command
                    i2c_data_w_char <= pos_data[char_flow_cnt]; // 取当前指令
                    char_flow_cnt   <= char_flow_cnt + 1'b1;
                end
            end else begin
                pos_set_done <= 1'b1;
                char_flow_cnt <= 1'b0;
            end
    end
    else begin 
        if(init_done && pos_set_done && !char_done)begin
            i2c_exec_char <= 1'b0;
            if (char_flow_cnt < CHAR_NUM) begin
                wait_cnt <= wait_cnt + 1'b1;
                if (wait_cnt == WR_WAIT_TIME - 1) begin
                    i2c_exec_char   <= 1'b1;
                    wait_cnt   <= 14'b0;
                    i2c_addr_char   <= 8'h40; // write data
                    i2c_data_w_char <= char_data[char_flow_cnt]; // 取当前指令
                    char_flow_cnt   <= char_flow_cnt + 1'b1;
                end
            end else begin
                char_done <= 1'b1;
            end
        end
    end
end

endmodule