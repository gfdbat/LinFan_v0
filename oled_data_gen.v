////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: OLED Display Data Generator
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
`include "bin_2_bcd.v"
module oled_data_gen(
    input clk,
    input rstn,

    input [11:0] temp,
    input [11:0] ctrl_speed,
    input [15:0] rpm,

    input   [7:0]  i2c_data_r,
    input   i2c_done,
    input   i2c_ack,
    output  reg i2c_rh_wl,
    output  reg i2c_exec,
    output  reg [15:0]  i2c_addr,
    output  reg [7:0]   i2c_data_w
);

parameter WR_WAIT_TIME = 31'd200; // Write operation interval 5000, 10000, 2000, 500
reg [9:0] flow_cnt;  // Flow control
reg [31:0] wait_cnt; // Delay counter

// When in S1 and S2, write Characters
// When in S3 and S4, write Waveforms
localparam S0_INIT = 0;
localparam S1_POS = 1;
localparam S2_CHAR = 2;
localparam S3_WAVE_POS = 3;
localparam S4_WAVE_DATA = 4;

// FSM signals
reg [3:0] state;
reg [3:0] next_state;

// display regs
reg [7:0] i2c_init_data [0:27];
reg [7:0] i2c_init_clear [3:0];
reg [7:0] pos_data [2:0];
reg [47:0] char_data [CHAR_NUM-1:0];
reg [47:0] num_lib [9:0];

reg [7:0] x_pos [CHAR_NUM-1:0];
reg [7:0] y_pos [CHAR_NUM-1:0];
reg [9:0] char_pos_cnt;
reg [3:0] clear_cnt_8;
reg [9:0] clear_cnt_3_128;

// operation done signals
reg init_command_done;
reg init_clear_done;
reg init_done;
reg pos_set_done_0;
reg pos_set_done;
reg char_done;
reg wave_pos_set_done_0;
reg wave_pos_set_done;
reg wave_done_single;
reg wave_done_whole;

reg [9:0] wave_pos_cnt;
reg [7:0] wave_x_pos [3:0];
reg [7:0] wave_y_pos [3:0];

// waveform flash indicators
reg [9:0] wave_flash_cnt;
reg wave_flash_flag;


parameter INIT_NUM = 28;        // # of initialization commands to issue
parameter POS_SET_NUM = 3;      // # of commands used to set a position
parameter PARTS_NUM = 6;        // # of columns to construct a character (8lines x 6columns)
parameter CHAR_NUM = 47;        // Total characters to display
parameter WAVE_PARTS_NUM = 128; // # of columns to construct a waveform (8lines x 128columns)
parameter WAVE_NUM = 4;         // Total waveforms to display


// Convert BIN data to BCD data for display
wire [15:0] temp_bcd;
bin_2_bcd #(
    .W(12)
)u_bin_bcd_temp(
    .bin(temp),
    .bcd(temp_bcd)
);

wire [15:0] speed_bcd;
bin_2_bcd #(
    .W(12)
)u_bin_bcd_speed(
    .bin(ctrl_speed),
    .bcd(speed_bcd)
);

wire [15:0] rpm_bcd;
bin_2_bcd #(
    .W(16)
)u_bin_bcd_rpm(
    .bin(rpm),
    .bcd(rpm_bcd)
);

always@(posedge clk or negedge rstn)begin
    if(~rstn)
        state <= S0_INIT;
    else
        state <= next_state;
end

// Next state logic
always@(*)begin
    case(state)
        S0_INIT:begin
            if(init_done)
                next_state = S1_POS;
            else
                next_state = S0_INIT;
        end
        S1_POS:begin
            if(pos_set_done)
                next_state = S2_CHAR;
            else
                next_state = S1_POS;
        end
        S2_CHAR:begin
            if(wave_flash_flag)
                next_state = S3_WAVE_POS;
            else if(char_done)
                next_state = S1_POS;
            else
                next_state = S2_CHAR;
        end
        S3_WAVE_POS:begin
            if(wave_pos_set_done)
                next_state = S4_WAVE_DATA;
            else
                next_state = S3_WAVE_POS;
        end        
        S4_WAVE_DATA:begin
            if(wave_done_whole)
                next_state = S1_POS;
            else if(wave_done_single)
                next_state = S3_WAVE_POS;
            else
                next_state = S4_WAVE_DATA;
        end
    endcase
end

// Pixel Data Generator
always@(posedge clk or negedge rstn)begin
    if(~rstn)begin
        i2c_exec <= 1'b0;
        i2c_addr <= 16'b0;
        i2c_data_w <= 8'b0;
        i2c_rh_wl <= 1'b0;
        /* Commands for initialization, Refer to Common HAL libs and SH1106 User Manual */
        i2c_init_data[0]  <= 8'hAE; 

        //i2c_init_data[1]  <= 8'h02;
        i2c_init_data[1]  <= 8'he3;
        //i2c_init_data[2]  <= 8'h10; 
        i2c_init_data[2]  <= 8'he3; 
        i2c_init_data[3]  <= 8'h40; // start line addr: 40
        //i2c_init_data[4]  <= 8'hB0; 
        i2c_init_data[4]  <= 8'he3; 

        i2c_init_data[5]  <= 8'h81;
        i2c_init_data[6]  <= 8'hFF; i2c_init_data[7]  <= 8'hA1; //A1
        i2c_init_data[8]  <= 8'hA6; i2c_init_data[9]  <= 8'hA8;
        i2c_init_data[10] <= 8'h3F; i2c_init_data[11] <= 8'hAD;
        i2c_init_data[12] <= 8'h8B; i2c_init_data[13] <= 8'h33;
        i2c_init_data[14] <= 8'hC8; i2c_init_data[15] <= 8'hD3;
        i2c_init_data[16] <= 8'h00; i2c_init_data[17] <= 8'hD5;
        i2c_init_data[18] <= 8'h80; i2c_init_data[19] <= 8'hD8;
        i2c_init_data[20] <= 8'h05; i2c_init_data[21] <= 8'hD9;
        i2c_init_data[22] <= 8'h1F; i2c_init_data[23] <= 8'hDA;
        i2c_init_data[24] <= 8'h12; i2c_init_data[25] <= 8'hDB;
        i2c_init_data[26] <= 8'h40; 
        i2c_init_data[27] <= 8'hAF;
        /* Commands for Clear */
        i2c_init_clear[0] <= 8'hb0;
        i2c_init_clear[1] <= 8'h02;
        i2c_init_clear[2] <= 8'h10;
        i2c_init_clear[3] <= 8'h00;
        init_done <= 1'b0;
        init_command_done <= 1'b0;
        init_clear_done <= 1'b0;
        clear_cnt_8 <= 1'b0;
        clear_cnt_3_128 <= 1'b0;
        
        /* Char Position Data */
        x_pos[0] <= 0; y_pos[0] <= 4;
        x_pos[1] <= 6; y_pos[1] <= 4;
        x_pos[2] <= 12; y_pos[2] <= 4;
        x_pos[3] <= 18; y_pos[3] <= 4;
        x_pos[4] <= 24; y_pos[4] <= 4;
        x_pos[5] <= 30; y_pos[5] <= 4;
        x_pos[6] <= 36; y_pos[6] <= 4;
        x_pos[7] <= 42; y_pos[7] <= 4;
        x_pos[8] <= 48; y_pos[8] <= 4;
        x_pos[9] <= 54; y_pos[9] <= 4;
        x_pos[10] <= 60; y_pos[10] <= 4;
        x_pos[11] <= 66; y_pos[11] <= 4;

        x_pos[12] <= 0; y_pos[12] <= 5;
        x_pos[13] <= 6; y_pos[13] <= 5;
        x_pos[14] <= 12; y_pos[14] <= 5;
        x_pos[15] <= 18; y_pos[15] <= 5;
        x_pos[16] <= 24; y_pos[16] <= 5;
        x_pos[17] <= 30; y_pos[17] <= 5;
        x_pos[18] <= 36; y_pos[18] <= 5;
        x_pos[19] <= 42; y_pos[19] <= 5;
        x_pos[20] <= 48; y_pos[20] <= 5;
        x_pos[21] <= 54; y_pos[21] <= 5;
        x_pos[22] <= 60; y_pos[22] <= 5;
        x_pos[23] <= 66; y_pos[23] <= 5;

        x_pos[24] <= 0; y_pos[24] <= 6;
        x_pos[25] <= 6; y_pos[25] <= 6;
        x_pos[26] <= 12; y_pos[26] <= 6;
        x_pos[27] <= 18; y_pos[27] <= 6;
        x_pos[28] <= 24; y_pos[28] <= 6;
        x_pos[29] <= 30; y_pos[29] <= 6;
        x_pos[30] <= 36; y_pos[30] <= 6;
        x_pos[31] <= 42; y_pos[31] <= 6;
        x_pos[32] <= 48; y_pos[32] <= 6;
        x_pos[33] <= 54; y_pos[33] <= 6;
        x_pos[34] <= 60; y_pos[34] <= 6;
        x_pos[35] <= 66; y_pos[35] <= 6;
        
        x_pos[36] <= 48; y_pos[36] <= 7;
        x_pos[37] <= 54; y_pos[37] <= 7; 
        x_pos[38] <= 60; y_pos[38] <= 7; 
        x_pos[39] <= 66; y_pos[39] <= 7; 
        x_pos[40] <= 72; y_pos[40] <= 7; 
        x_pos[41] <= 78; y_pos[41] <= 7; 

        x_pos[42] <= 90; y_pos[42] <= 7; 
        x_pos[43] <= 96; y_pos[43] <= 7; 

        x_pos[44] <= 108; y_pos[44] <= 7; 
        x_pos[45] <= 114; y_pos[45] <= 7; 
        x_pos[46] <= 120; y_pos[46] <= 7; 

        
        pos_data[0] <= 0;
        pos_data[1] <= 0;
        pos_data[2] <= 0;
        char_pos_cnt <= 0;


        pos_set_done_0 <= 0;
        pos_set_done <= 0;
        char_done <= 0;

        flow_cnt <= 0;

        wave_pos_cnt <= 0;
        wave_pos_set_done_0 <= 0;
        wave_pos_set_done <= 0;
        wave_done_single <= 0;
        wave_done_whole <= 0;


        wave_x_pos[0] <= 0; wave_y_pos[0] <= 3;
        wave_x_pos[1] <= 0; wave_y_pos[1] <= 2;
        wave_x_pos[2] <= 0; wave_y_pos[2] <= 1;
        wave_x_pos[3] <= 0; wave_y_pos[3] <= 0;

        wave_flash_cnt <= 0;
        wave_flash_flag <= 0;


    end else begin
        case(state)
        // Initialization State
        S0_INIT:begin
            if(~init_command_done)begin
                i2c_exec <= 1'b0;
                if (flow_cnt < INIT_NUM) begin
                    wait_cnt <= wait_cnt + 1'b1;
                    if (wait_cnt == WR_WAIT_TIME - 1) begin
                        wait_cnt <= 1'b0;
                        i2c_exec <= 1'b1;
                        i2c_addr <= 8'h00; // write command
                        i2c_data_w <= i2c_init_data[flow_cnt]; // 取当前指令
                        flow_cnt <= flow_cnt + 1'b1;
                    end
                end else begin
                    init_command_done <= 1'b1;
                    flow_cnt <= 1'b0;
                end
            end else if(~init_clear_done)begin
                i2c_exec <= 1'b0;
                if (clear_cnt_8 < 8) begin
                    wait_cnt <= wait_cnt + 1'b1;
                    if (wait_cnt == WR_WAIT_TIME - 1) begin
                        wait_cnt <= 1'b0;
                        i2c_exec <= 1'b1;

                        i2c_addr <= (clear_cnt_3_128 < 3)? 8'h00 : 8'h40;
                        i2c_data_w <= (clear_cnt_3_128 < 3)? i2c_init_clear[clear_cnt_3_128]: i2c_init_clear[3];
                        case(clear_cnt_3_128)
                            0: i2c_data_w <= i2c_init_clear[0] + clear_cnt_8;
                            1: i2c_data_w <= i2c_init_clear[1];
                            2: i2c_data_w <= i2c_init_clear[2];
                            default: i2c_data_w <= i2c_init_clear[3];
                        endcase
                        if(clear_cnt_3_128 == 10'd130)begin
                            clear_cnt_8 <= clear_cnt_8 + 1;
                            clear_cnt_3_128 <= 1'b0;
                        end else begin
                            clear_cnt_3_128 <= clear_cnt_3_128 + 1'b1;
                        end
                    end
                end else begin
                    init_clear_done <= 1'b1;
                    init_done <= 1'b1;
                    clear_cnt_3_128 <= 1'b0;
                end
            end
        end
        // Set position for a single character
        S1_POS:begin
            i2c_exec <= 1'b0;
            if(~pos_set_done_0)begin
                pos_data[0] <= 8'hb0 + y_pos[char_pos_cnt];
                pos_data[1] <= ((x_pos[char_pos_cnt] & 8'hf0) >> 4) | 8'h10;
                pos_data[2] <= (x_pos[char_pos_cnt] & 8'h0f) | 8'h01;
                pos_set_done_0 <= 1'b1;
            end else if (flow_cnt < POS_SET_NUM) begin
                wait_cnt <= wait_cnt + 1'b1;
                if(i2c_done)begin
                    i2c_addr <= 8'h00; // write command
                    i2c_data_w <= pos_data[flow_cnt]; // 取当前指令
                end
                if (wait_cnt == WR_WAIT_TIME - 1) begin
                    wait_cnt <= 1'b0;
                    i2c_exec <= 1'b1;
                    flow_cnt <= flow_cnt + 1'b1;
                end
            end else begin
                pos_set_done <= 1'b1;
                flow_cnt <= 1'b0;
                char_done <= 1'b0;
                i2c_addr <= 8'h40;
            end
        end
        // Display a single character with index 'char_pos_cnt'
        S2_CHAR:begin
            i2c_exec <= 1'b0;
            if (flow_cnt < PARTS_NUM) begin
                wait_cnt <= wait_cnt + 1'b1;
                if(i2c_done)begin
                    i2c_addr   <= 8'h40; // write data
                    case(flow_cnt)
                        0: i2c_data_w <= char_data[char_pos_cnt][7:0];
                        1: i2c_data_w <= char_data[char_pos_cnt][15:8];
                        2: i2c_data_w <= char_data[char_pos_cnt][23:16];
                        3: i2c_data_w <= char_data[char_pos_cnt][31:24];
                        4: i2c_data_w <= char_data[char_pos_cnt][39:32];
                        5: i2c_data_w <= char_data[char_pos_cnt][47:40];
                        default : i2c_data_w <= char_data[char_pos_cnt][7:0];
                    endcase
                end
                if (wait_cnt == WR_WAIT_TIME - 1) begin
                    wait_cnt   <= 1'b0;
                    i2c_exec <= 1'b1;
                    flow_cnt   <= flow_cnt + 1'b1;
                end
            end else begin
                char_done <= 1'b1;
                pos_set_done_0 <= 1'b0;
                pos_set_done <= 1'b0;
                flow_cnt <= 1'b0;
                if(char_pos_cnt == CHAR_NUM - 1)
                    char_pos_cnt <= 1'b0;
                else
                    char_pos_cnt <= char_pos_cnt + 1'b1; 
                i2c_addr <= 8'h00;

                wave_flash_cnt <= wave_flash_cnt + 1'b1;
                if(wave_flash_cnt == 7)begin //////////////// 77
                    wave_flash_flag <= 1'b1;
                    wave_flash_cnt <= 0;
                end
                wave_done_whole <= 1'b0;
            end
        end
        // Set position for a single page of waveform
        S3_WAVE_POS:begin
            i2c_exec <= 1'b0;
            if(~wave_pos_set_done_0)begin
                pos_data[0] <= 8'hb0 + wave_y_pos[wave_pos_cnt];
                pos_data[1] <= ((wave_x_pos[wave_pos_cnt] & 8'hf0) >> 4) | 8'h10;
                pos_data[2] <= (wave_x_pos[wave_pos_cnt] & 8'h0f) | 8'h01;
                wave_pos_set_done_0 <= 1'b1;
            end else if (flow_cnt < POS_SET_NUM) begin
                wait_cnt <= wait_cnt + 1'b1;
                if(i2c_done)begin
                    i2c_addr <= 8'h00; // write command
                    i2c_data_w <= pos_data[flow_cnt]; // 取当前指令
                end
                if (wait_cnt == WR_WAIT_TIME - 1) begin
                    wait_cnt <= 1'b0;
                    i2c_exec <= 1'b1;
                    flow_cnt <= flow_cnt + 1'b1;
                end
            end else begin
                wave_pos_set_done <= 1'b1;
                flow_cnt <= 1'b0;
                i2c_addr <= 8'h40;
                wave_done_single <= 1'b0;
            end
        end
        // Display a single page of waveform with index 'wave_pos_cnt'
        S4_WAVE_DATA:begin
            i2c_exec <= 1'b0;
            if (flow_cnt < WAVE_PARTS_NUM) begin
                wait_cnt <= wait_cnt + 1'b1;
                if(i2c_done)begin
                    i2c_addr   <= 8'h40; // write data
                    case(flow_cnt)
                        0: i2c_data_w <= waved[wave_pos_cnt][7:0];
                        1: i2c_data_w <= waved[wave_pos_cnt][15:8];
                        2: i2c_data_w <= waved[wave_pos_cnt][23:16];
                        3: i2c_data_w <= waved[wave_pos_cnt][31:24];
                        4: i2c_data_w <= waved[wave_pos_cnt][39:32];
                        5: i2c_data_w <= waved[wave_pos_cnt][47:40];
                        6: i2c_data_w <= waved[wave_pos_cnt][55:48];
                        7: i2c_data_w <= waved[wave_pos_cnt][63:56];
                        8: i2c_data_w <= waved[wave_pos_cnt][71:64];
                        9: i2c_data_w <= waved[wave_pos_cnt][79:72];
                        10: i2c_data_w <= waved[wave_pos_cnt][87:80];
                        11: i2c_data_w <= waved[wave_pos_cnt][95:88];
                        12: i2c_data_w <= waved[wave_pos_cnt][103:96];
                        13: i2c_data_w <= waved[wave_pos_cnt][111:104];
                        14: i2c_data_w <= waved[wave_pos_cnt][119:112];
                        15: i2c_data_w <= waved[wave_pos_cnt][127:120];
                        16: i2c_data_w <= waved[wave_pos_cnt][135:128];
                        17: i2c_data_w <= waved[wave_pos_cnt][143:136];
                        18: i2c_data_w <= waved[wave_pos_cnt][151:144];
                        19: i2c_data_w <= waved[wave_pos_cnt][159:152];
                        20: i2c_data_w <= waved[wave_pos_cnt][167:160];
                        21: i2c_data_w <= waved[wave_pos_cnt][175:168];
                        22: i2c_data_w <= waved[wave_pos_cnt][183:176];
                        23: i2c_data_w <= waved[wave_pos_cnt][191:184];
                        24: i2c_data_w <= waved[wave_pos_cnt][199:192];
                        25: i2c_data_w <= waved[wave_pos_cnt][207:200];
                        26: i2c_data_w <= waved[wave_pos_cnt][215:208];
                        27: i2c_data_w <= waved[wave_pos_cnt][223:216];
                        28: i2c_data_w <= waved[wave_pos_cnt][231:224];
                        29: i2c_data_w <= waved[wave_pos_cnt][239:232];
                        30: i2c_data_w <= waved[wave_pos_cnt][247:240];
                        31: i2c_data_w <= waved[wave_pos_cnt][255:248];
                        32: i2c_data_w <= waved[wave_pos_cnt][263:256];
                        33: i2c_data_w <= waved[wave_pos_cnt][271:264];
                        34: i2c_data_w <= waved[wave_pos_cnt][279:272];
                        35: i2c_data_w <= waved[wave_pos_cnt][287:280];
                        36: i2c_data_w <= waved[wave_pos_cnt][295:288];
                        37: i2c_data_w <= waved[wave_pos_cnt][303:296];
                        38: i2c_data_w <= waved[wave_pos_cnt][311:304];
                        39: i2c_data_w <= waved[wave_pos_cnt][319:312];
                        40: i2c_data_w <= waved[wave_pos_cnt][327:320];
                        41: i2c_data_w <= waved[wave_pos_cnt][335:328];
                        42: i2c_data_w <= waved[wave_pos_cnt][343:336];
                        43: i2c_data_w <= waved[wave_pos_cnt][351:344];
                        44: i2c_data_w <= waved[wave_pos_cnt][359:352];
                        45: i2c_data_w <= waved[wave_pos_cnt][367:360];
                        46: i2c_data_w <= waved[wave_pos_cnt][375:368];
                        47: i2c_data_w <= waved[wave_pos_cnt][383:376];
                        48: i2c_data_w <= waved[wave_pos_cnt][391:384];
                        49: i2c_data_w <= waved[wave_pos_cnt][399:392];
                        50: i2c_data_w <= waved[wave_pos_cnt][407:400];
                        51: i2c_data_w <= waved[wave_pos_cnt][415:408];
                        52: i2c_data_w <= waved[wave_pos_cnt][423:416];
                        53: i2c_data_w <= waved[wave_pos_cnt][431:424];
                        54: i2c_data_w <= waved[wave_pos_cnt][439:432];
                        55: i2c_data_w <= waved[wave_pos_cnt][447:440];
                        56: i2c_data_w <= waved[wave_pos_cnt][455:448];
                        57: i2c_data_w <= waved[wave_pos_cnt][463:456];
                        58: i2c_data_w <= waved[wave_pos_cnt][471:464];
                        59: i2c_data_w <= waved[wave_pos_cnt][479:472];
                        60: i2c_data_w <= waved[wave_pos_cnt][487:480];
                        61: i2c_data_w <= waved[wave_pos_cnt][495:488];
                        62: i2c_data_w <= waved[wave_pos_cnt][503:496];
                        63: i2c_data_w <= waved[wave_pos_cnt][511:504];
                        64: i2c_data_w <= waved[wave_pos_cnt][519:512];
                        65: i2c_data_w <= waved[wave_pos_cnt][527:520];
                        66: i2c_data_w <= waved[wave_pos_cnt][535:528];
                        67: i2c_data_w <= waved[wave_pos_cnt][543:536];
                        68: i2c_data_w <= waved[wave_pos_cnt][551:544];
                        69: i2c_data_w <= waved[wave_pos_cnt][559:552];
                        70: i2c_data_w <= waved[wave_pos_cnt][567:560];
                        71: i2c_data_w <= waved[wave_pos_cnt][575:568];
                        72: i2c_data_w <= waved[wave_pos_cnt][583:576];
                        73: i2c_data_w <= waved[wave_pos_cnt][591:584];
                        74: i2c_data_w <= waved[wave_pos_cnt][599:592];
                        75: i2c_data_w <= waved[wave_pos_cnt][607:600];
                        76: i2c_data_w <= waved[wave_pos_cnt][615:608];
                        77: i2c_data_w <= waved[wave_pos_cnt][623:616];
                        78: i2c_data_w <= waved[wave_pos_cnt][631:624];
                        79: i2c_data_w <= waved[wave_pos_cnt][639:632];
                        80: i2c_data_w <= waved[wave_pos_cnt][647:640];
                        81: i2c_data_w <= waved[wave_pos_cnt][655:648];
                        82: i2c_data_w <= waved[wave_pos_cnt][663:656];
                        83: i2c_data_w <= waved[wave_pos_cnt][671:664];
                        84: i2c_data_w <= waved[wave_pos_cnt][679:672];
                        85: i2c_data_w <= waved[wave_pos_cnt][687:680];
                        86: i2c_data_w <= waved[wave_pos_cnt][695:688];
                        87: i2c_data_w <= waved[wave_pos_cnt][703:696];
                        88: i2c_data_w <= waved[wave_pos_cnt][711:704];
                        89: i2c_data_w <= waved[wave_pos_cnt][719:712];
                        90: i2c_data_w <= waved[wave_pos_cnt][727:720];
                        91: i2c_data_w <= waved[wave_pos_cnt][735:728];
                        92: i2c_data_w <= waved[wave_pos_cnt][743:736];
                        93: i2c_data_w <= waved[wave_pos_cnt][751:744];
                        94: i2c_data_w <= waved[wave_pos_cnt][759:752];
                        95: i2c_data_w <= waved[wave_pos_cnt][767:760];
                        96: i2c_data_w <= waved[wave_pos_cnt][775:768];
                        97: i2c_data_w <= waved[wave_pos_cnt][783:776];
                        98: i2c_data_w <= waved[wave_pos_cnt][791:784];
                        99: i2c_data_w <= waved[wave_pos_cnt][799:792];
                        100: i2c_data_w <= waved[wave_pos_cnt][807:800];
                        101: i2c_data_w <= waved[wave_pos_cnt][815:808];
                        102: i2c_data_w <= waved[wave_pos_cnt][823:816];
                        103: i2c_data_w <= waved[wave_pos_cnt][831:824];
                        104: i2c_data_w <= waved[wave_pos_cnt][839:832];
                        105: i2c_data_w <= waved[wave_pos_cnt][847:840];
                        106: i2c_data_w <= waved[wave_pos_cnt][855:848];
                        107: i2c_data_w <= waved[wave_pos_cnt][863:856];
                        108: i2c_data_w <= waved[wave_pos_cnt][871:864];
                        109: i2c_data_w <= waved[wave_pos_cnt][879:872];
                        110: i2c_data_w <= waved[wave_pos_cnt][887:880];
                        111: i2c_data_w <= waved[wave_pos_cnt][895:888];
                        112: i2c_data_w <= waved[wave_pos_cnt][903:896];
                        113: i2c_data_w <= waved[wave_pos_cnt][911:904];
                        114: i2c_data_w <= waved[wave_pos_cnt][919:912];
                        115: i2c_data_w <= waved[wave_pos_cnt][927:920];
                        116: i2c_data_w <= waved[wave_pos_cnt][935:928];
                        117: i2c_data_w <= waved[wave_pos_cnt][943:936];
                        118: i2c_data_w <= waved[wave_pos_cnt][951:944];
                        119: i2c_data_w <= waved[wave_pos_cnt][959:952];
                        120: i2c_data_w <= waved[wave_pos_cnt][967:960];
                        121: i2c_data_w <= waved[wave_pos_cnt][975:968];
                        122: i2c_data_w <= waved[wave_pos_cnt][983:976];
                        123: i2c_data_w <= waved[wave_pos_cnt][991:984];
                        124: i2c_data_w <= waved[wave_pos_cnt][999:992];
                        125: i2c_data_w <= waved[wave_pos_cnt][1007:1000];
                        126: i2c_data_w <= waved[wave_pos_cnt][1015:1008];
                        127: i2c_data_w <= waved[wave_pos_cnt][1023:1016];
                        default : i2c_data_w <= waved[wave_pos_cnt][7:0];
                    endcase
                end
                if (wait_cnt == WR_WAIT_TIME - 1) begin
                    wait_cnt   <= 1'b0;
                    i2c_exec <= 1'b1;
                    flow_cnt   <= flow_cnt + 1'b1;
                end
            end else begin
                wave_done_single <= 1'b1;
                wave_pos_set_done_0 <= 1'b0;
                wave_pos_set_done <= 1'b0;
                flow_cnt <= 1'b0;
                if(wave_pos_cnt == WAVE_NUM - 1)begin
                    wave_pos_cnt <= 1'b0;
                    wave_done_whole <= 1'b1;
                end else
                    wave_pos_cnt <= wave_pos_cnt + 1'b1; 
                i2c_addr <= 8'h00;
                wave_flash_flag <= 1'b0;
            end
        end
        endcase
    end
end


// Setup a 0-9 Number Libary
always@(posedge clk or negedge rstn)begin
    if(~rstn)begin
    num_lib[0] <= 48'h3e4549513e00; // 0
    num_lib[1] <= 48'h00407f420000;
    num_lib[2] <= 48'h464951614200;
    num_lib[3] <= 48'h314b45412100;
    num_lib[4] <= 48'h107f12141800;
    num_lib[5] <= 48'h394545452700;
    num_lib[6] <= 48'h3049494a3c00;
    num_lib[7] <= 48'h030509710100;
    num_lib[8] <= 48'h364949493600;
    num_lib[9] <= 48'h1e2949490600; // 9
    end
end

// Temperature BCD buffer

reg [15:0] temp_bcd_load;

parameter CNT_MAX = 150000; /* f=50MHz(T=20ns) => T'=1s */
//parameter CNT_MAX = 25472; /* f=50MHz(T=20ns) => T'=1s */
reg [31:0] cnt_01;
wire clk_01;

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

assign clk_01 = (cnt_01 == CNT_MAX - 1);

always@(posedge clk_01 or negedge rstn)begin
    if(~rstn)begin
        temp_bcd_load <= 16'b0;
    end else begin
        temp_bcd_load <= temp_bcd;
    end
end

// load character data
always@(*)begin
    char_data[0] = 48'h01017f010100; // T
    char_data[1] = 48'h185454543800; // e
    char_data[2] = 48'h780418047c00; // m
    char_data[3] = 48'h18242424fc00; // p
    char_data[4] = 48'h000036360000; // :
    char_data[5] = 48'h000000000000;
    char_data[6] = 48'h000000000000;
    char_data[7] = 48'h000000000000;
    char_data[8] = 48'h000060600000; // .
    char_data[9] = 48'h000000000000;
    char_data[10] = 48'h000006060000; // du
    char_data[11] = 48'h224141413e00; // C

    char_data[12] = 48'h314949494600; // S
    char_data[13] = 48'h18242424fc00; // p
    char_data[14] = 48'h185454543800; // e
    char_data[15] = 48'h185454543800; // e
    char_data[16] = 48'h7f4844443800; // d
    char_data[17] = 48'h000036360000; // :
    char_data[18] = 48'h000000000000; // 1
    char_data[19] = 48'h000000000000; 
    char_data[20] = 48'h000000000000; 
    char_data[21] = 48'h000000000000; // 4
    char_data[22] = 48'h000000000000;
    char_data[23] = 48'h000000000000;

    char_data[24] = 48'h462919097f00; // R
    char_data[25] = 48'h060909097f00; // P
    char_data[26] = 48'h7f020c027f00; // M
    char_data[27] = 48'h000036360000; // :
    char_data[28] = 48'h000000000000; // 
    char_data[29] = 48'h000000000000; // 1
    char_data[30] = 48'h000000000000; // 2
    char_data[31] = 48'h000000000000; // 3
    char_data[32] = 48'h000000000000; // 4
    char_data[33] = 48'h000000000000;
    char_data[34] = 48'h000000000000;
    char_data[35] = 48'h000000000000;

    char_data[36] = 48'h404040407F00; //L
    char_data[37] = 48'h00007d000000; //i 00407d440000
    char_data[38] = 48'h780404047800; //n 780404087c00
    char_data[39] = 48'h010909097f00; //F
    char_data[40] = 48'h784444443800; //a 785454542000
    char_data[41] = 48'h780404047840; //n

    char_data[42] = 48'h384444487f00; //b
    char_data[43] = 48'h0c1030488400; //y 7ca0a0a01c00

    char_data[44] = 48'h181818000000; //Y
    char_data[45] = 48'h422418182442; //X
    char_data[46] = 48'h000008182848; //G    

    // load temperature data
    case(temp_bcd_load[11:8])
        0: char_data[6] = num_lib[0];
        1: char_data[6] = num_lib[1];
        2: char_data[6] = num_lib[2];
        3: char_data[6] = num_lib[3];
        4: char_data[6] = num_lib[4];
        5: char_data[6] = num_lib[5];
        6: char_data[6] = num_lib[6];
        7: char_data[6] = num_lib[7];
        8: char_data[6] = num_lib[8];
        9: char_data[6] = num_lib[9];
        default: char_data[6] = num_lib[0];
    endcase
    case(temp_bcd_load[7:4])
        0: char_data[7] = num_lib[0];
        1: char_data[7] = num_lib[1];
        2: char_data[7] = num_lib[2];
        3: char_data[7] = num_lib[3];
        4: char_data[7] = num_lib[4];
        5: char_data[7] = num_lib[5];
        6: char_data[7] = num_lib[6];
        7: char_data[7] = num_lib[7];
        8: char_data[7] = num_lib[8];
        9: char_data[7] = num_lib[9];
        default: char_data[7] = num_lib[0];
    endcase        
    case(temp_bcd_load[3:0])
        0: char_data[9] = num_lib[0];
        1: char_data[9] = num_lib[1];
        2: char_data[9] = num_lib[2];
        3: char_data[9] = num_lib[3];
        4: char_data[9] = num_lib[4];
        5: char_data[9] = num_lib[5];
        6: char_data[9] = num_lib[6];
        7: char_data[9] = num_lib[7];
        8: char_data[9] = num_lib[8];
        9: char_data[9] = num_lib[9];
        default: char_data[9] = num_lib[0];
    endcase

    // load RPM data
    case(rpm_bcd[15:12])
        0: char_data[29] = num_lib[0];
        1: char_data[29] = num_lib[1];
        2: char_data[29] = num_lib[2];
        3: char_data[29] = num_lib[3];
        4: char_data[29] = num_lib[4];
        5: char_data[29] = num_lib[5];
        6: char_data[29] = num_lib[6];
        7: char_data[29] = num_lib[7];
        8: char_data[29] = num_lib[8];
        9: char_data[29] = num_lib[9];
        default: char_data[29] = num_lib[0];
    endcase
    case(rpm_bcd[11:8])
        0: char_data[30] = num_lib[0];
        1: char_data[30] = num_lib[1];
        2: char_data[30] = num_lib[2];
        3: char_data[30] = num_lib[3];
        4: char_data[30] = num_lib[4];
        5: char_data[30] = num_lib[5];
        6: char_data[30] = num_lib[6];
        7: char_data[30] = num_lib[7];
        8: char_data[30] = num_lib[8];
        9: char_data[30] = num_lib[9];
        default: char_data[30] = num_lib[0];
    endcase
    case(rpm_bcd[7:4])
        0: char_data[31] = num_lib[0];
        1: char_data[31] = num_lib[1];
        2: char_data[31] = num_lib[2];
        3: char_data[31] = num_lib[3];
        4: char_data[31] = num_lib[4];
        5: char_data[31] = num_lib[5];
        6: char_data[31] = num_lib[6];
        7: char_data[31] = num_lib[7];
        8: char_data[31] = num_lib[8];
        9: char_data[31] = num_lib[9];
        default: char_data[31] = num_lib[0];
    endcase        
    case(rpm_bcd[3:0])
        0: char_data[32] = num_lib[0];
        1: char_data[32] = num_lib[1];
        2: char_data[32] = num_lib[2];
        3: char_data[32] = num_lib[3];
        4: char_data[32] = num_lib[4];
        5: char_data[32] = num_lib[5];
        6: char_data[32] = num_lib[6];
        7: char_data[32] = num_lib[7];
        8: char_data[32] = num_lib[8];
        9: char_data[32] = num_lib[9];
        default: char_data[32] = num_lib[0];
    endcase


    // load Control Speed data
    case(speed_bcd[15:12])
        0: char_data[18] = num_lib[0];
        1: char_data[18] = num_lib[1];
        2: char_data[18] = num_lib[2];
        3: char_data[18] = num_lib[3];
        4: char_data[18] = num_lib[4];
        5: char_data[18] = num_lib[5];
        6: char_data[18] = num_lib[6];
        7: char_data[18] = num_lib[7];
        8: char_data[18] = num_lib[8];
        9: char_data[18] = num_lib[9];
        default: char_data[18] = num_lib[0];
    endcase
    case(speed_bcd[11:8])
        0: char_data[19] = num_lib[0];
        1: char_data[19] = num_lib[1];
        2: char_data[19] = num_lib[2];
        3: char_data[19] = num_lib[3];
        4: char_data[19] = num_lib[4];
        5: char_data[19] = num_lib[5];
        6: char_data[19] = num_lib[6];
        7: char_data[19] = num_lib[7];
        8: char_data[19] = num_lib[8];
        9: char_data[19] = num_lib[9];
        default: char_data[19] = num_lib[0];
    endcase
    case(speed_bcd[7:4])
        0: char_data[20] = num_lib[0];
        1: char_data[20] = num_lib[1];
        2: char_data[20] = num_lib[2];
        3: char_data[20] = num_lib[3];
        4: char_data[20] = num_lib[4];
        5: char_data[20] = num_lib[5];
        6: char_data[20] = num_lib[6];
        7: char_data[20] = num_lib[7];
        8: char_data[20] = num_lib[8];
        9: char_data[20] = num_lib[9];
        default: char_data[20] = num_lib[0];
    endcase        
    case(speed_bcd[3:0])
        0: char_data[21] = num_lib[0];
        1: char_data[21] = num_lib[1];
        2: char_data[21] = num_lib[2];
        3: char_data[21] = num_lib[3];
        4: char_data[21] = num_lib[4];
        5: char_data[21] = num_lib[5];
        6: char_data[21] = num_lib[6];
        7: char_data[21] = num_lib[7];
        8: char_data[21] = num_lib[8];
        9: char_data[21] = num_lib[9];
        default: char_data[21] = num_lib[0];
    endcase
end

// Generate the waveform (generate the first column to be sent to the shift registers set)
wire [4:0] temp_mapped;
assign temp_mapped = (temp >> 4) - 10;
wire [31:0] temp_waved; 
assign temp_waved = 32'b1 << temp_mapped | ((32'b1 << temp_mapped) >> 1) | ((32'b1 << temp_mapped) << 1);

wire [4:0] rpm_mapped;
assign rpm_mapped = rpm >> 8; 
wire [31:0] rpm_waved; 
assign rpm_waved = 32'b1 << rpm_mapped;

wire [31:0] overall_waved_fliped, ow;
assign ow = temp_waved ^ rpm_waved;
assign overall_waved_fliped = {ow[24],ow[25],ow[26],ow[27],ow[28],ow[29],ow[30],ow[31],ow[16],ow[17],ow[18],ow[19],ow[20],ow[21],ow[22],ow[23],ow[8],ow[9],ow[10],ow[11],ow[12],ow[13],ow[14],ow[15],ow[0],ow[1],ow[2],ow[3],ow[4],ow[5],ow[6],ow[7]};

reg [1023:0] waved [3:0]; // Total 4 pages

// When flash singal comes, update the waveform
always@(posedge wave_flash_flag or negedge rstn)begin
    if(~rstn)begin
        waved[3] <= 1'b0;
        waved[2] <= 1'b0;
        waved[1] <= 1'b0;
        waved[0] <= 1'b0;
    end else begin
        {waved[3][1023:1016],waved[2][1023:1016],waved[1][1023:1016],waved[0][1023:1016]} <= overall_waved_fliped;
        {waved[3][1015:1008],waved[2][1015:1008],waved[1][1015:1008],waved[0][1015:1008]} <= {waved[3][1023:1016],waved[2][1023:1016],waved[1][1023:1016],waved[0][1023:1016]};
        {waved[3][1007:1000],waved[2][1007:1000],waved[1][1007:1000],waved[0][1007:1000]} <= {waved[3][1015:1008],waved[2][1015:1008],waved[1][1015:1008],waved[0][1015:1008]};
        {waved[3][999:992],waved[2][999:992],waved[1][999:992],waved[0][999:992]} <= {waved[3][1007:1000],waved[2][1007:1000],waved[1][1007:1000],waved[0][1007:1000]};
        {waved[3][991:984],waved[2][991:984],waved[1][991:984],waved[0][991:984]} <= {waved[3][999:992],waved[2][999:992],waved[1][999:992],waved[0][999:992]};
        {waved[3][983:976],waved[2][983:976],waved[1][983:976],waved[0][983:976]} <= {waved[3][991:984],waved[2][991:984],waved[1][991:984],waved[0][991:984]};
        {waved[3][975:968],waved[2][975:968],waved[1][975:968],waved[0][975:968]} <= {waved[3][983:976],waved[2][983:976],waved[1][983:976],waved[0][983:976]};
        {waved[3][967:960],waved[2][967:960],waved[1][967:960],waved[0][967:960]} <= {waved[3][975:968],waved[2][975:968],waved[1][975:968],waved[0][975:968]};
        {waved[3][959:952],waved[2][959:952],waved[1][959:952],waved[0][959:952]} <= {waved[3][967:960],waved[2][967:960],waved[1][967:960],waved[0][967:960]};
        {waved[3][951:944],waved[2][951:944],waved[1][951:944],waved[0][951:944]} <= {waved[3][959:952],waved[2][959:952],waved[1][959:952],waved[0][959:952]};
        {waved[3][943:936],waved[2][943:936],waved[1][943:936],waved[0][943:936]} <= {waved[3][951:944],waved[2][951:944],waved[1][951:944],waved[0][951:944]};
        {waved[3][935:928],waved[2][935:928],waved[1][935:928],waved[0][935:928]} <= {waved[3][943:936],waved[2][943:936],waved[1][943:936],waved[0][943:936]};
        {waved[3][927:920],waved[2][927:920],waved[1][927:920],waved[0][927:920]} <= {waved[3][935:928],waved[2][935:928],waved[1][935:928],waved[0][935:928]};
        {waved[3][919:912],waved[2][919:912],waved[1][919:912],waved[0][919:912]} <= {waved[3][927:920],waved[2][927:920],waved[1][927:920],waved[0][927:920]};
        {waved[3][911:904],waved[2][911:904],waved[1][911:904],waved[0][911:904]} <= {waved[3][919:912],waved[2][919:912],waved[1][919:912],waved[0][919:912]};
        {waved[3][903:896],waved[2][903:896],waved[1][903:896],waved[0][903:896]} <= {waved[3][911:904],waved[2][911:904],waved[1][911:904],waved[0][911:904]};
        {waved[3][895:888],waved[2][895:888],waved[1][895:888],waved[0][895:888]} <= {waved[3][903:896],waved[2][903:896],waved[1][903:896],waved[0][903:896]};
        {waved[3][887:880],waved[2][887:880],waved[1][887:880],waved[0][887:880]} <= {waved[3][895:888],waved[2][895:888],waved[1][895:888],waved[0][895:888]};
        {waved[3][879:872],waved[2][879:872],waved[1][879:872],waved[0][879:872]} <= {waved[3][887:880],waved[2][887:880],waved[1][887:880],waved[0][887:880]};
        {waved[3][871:864],waved[2][871:864],waved[1][871:864],waved[0][871:864]} <= {waved[3][879:872],waved[2][879:872],waved[1][879:872],waved[0][879:872]};
        {waved[3][863:856],waved[2][863:856],waved[1][863:856],waved[0][863:856]} <= {waved[3][871:864],waved[2][871:864],waved[1][871:864],waved[0][871:864]};
        {waved[3][855:848],waved[2][855:848],waved[1][855:848],waved[0][855:848]} <= {waved[3][863:856],waved[2][863:856],waved[1][863:856],waved[0][863:856]};
        {waved[3][847:840],waved[2][847:840],waved[1][847:840],waved[0][847:840]} <= {waved[3][855:848],waved[2][855:848],waved[1][855:848],waved[0][855:848]};
        {waved[3][839:832],waved[2][839:832],waved[1][839:832],waved[0][839:832]} <= {waved[3][847:840],waved[2][847:840],waved[1][847:840],waved[0][847:840]};
        {waved[3][831:824],waved[2][831:824],waved[1][831:824],waved[0][831:824]} <= {waved[3][839:832],waved[2][839:832],waved[1][839:832],waved[0][839:832]};
        {waved[3][823:816],waved[2][823:816],waved[1][823:816],waved[0][823:816]} <= {waved[3][831:824],waved[2][831:824],waved[1][831:824],waved[0][831:824]};
        {waved[3][815:808],waved[2][815:808],waved[1][815:808],waved[0][815:808]} <= {waved[3][823:816],waved[2][823:816],waved[1][823:816],waved[0][823:816]};
        {waved[3][807:800],waved[2][807:800],waved[1][807:800],waved[0][807:800]} <= {waved[3][815:808],waved[2][815:808],waved[1][815:808],waved[0][815:808]};
        {waved[3][799:792],waved[2][799:792],waved[1][799:792],waved[0][799:792]} <= {waved[3][807:800],waved[2][807:800],waved[1][807:800],waved[0][807:800]};
        {waved[3][791:784],waved[2][791:784],waved[1][791:784],waved[0][791:784]} <= {waved[3][799:792],waved[2][799:792],waved[1][799:792],waved[0][799:792]};
        {waved[3][783:776],waved[2][783:776],waved[1][783:776],waved[0][783:776]} <= {waved[3][791:784],waved[2][791:784],waved[1][791:784],waved[0][791:784]};
        {waved[3][775:768],waved[2][775:768],waved[1][775:768],waved[0][775:768]} <= {waved[3][783:776],waved[2][783:776],waved[1][783:776],waved[0][783:776]};
        {waved[3][767:760],waved[2][767:760],waved[1][767:760],waved[0][767:760]} <= {waved[3][775:768],waved[2][775:768],waved[1][775:768],waved[0][775:768]};
        {waved[3][759:752],waved[2][759:752],waved[1][759:752],waved[0][759:752]} <= {waved[3][767:760],waved[2][767:760],waved[1][767:760],waved[0][767:760]};
        {waved[3][751:744],waved[2][751:744],waved[1][751:744],waved[0][751:744]} <= {waved[3][759:752],waved[2][759:752],waved[1][759:752],waved[0][759:752]};
        {waved[3][743:736],waved[2][743:736],waved[1][743:736],waved[0][743:736]} <= {waved[3][751:744],waved[2][751:744],waved[1][751:744],waved[0][751:744]};
        {waved[3][735:728],waved[2][735:728],waved[1][735:728],waved[0][735:728]} <= {waved[3][743:736],waved[2][743:736],waved[1][743:736],waved[0][743:736]};
        {waved[3][727:720],waved[2][727:720],waved[1][727:720],waved[0][727:720]} <= {waved[3][735:728],waved[2][735:728],waved[1][735:728],waved[0][735:728]};
        {waved[3][719:712],waved[2][719:712],waved[1][719:712],waved[0][719:712]} <= {waved[3][727:720],waved[2][727:720],waved[1][727:720],waved[0][727:720]};
        {waved[3][711:704],waved[2][711:704],waved[1][711:704],waved[0][711:704]} <= {waved[3][719:712],waved[2][719:712],waved[1][719:712],waved[0][719:712]};
        {waved[3][703:696],waved[2][703:696],waved[1][703:696],waved[0][703:696]} <= {waved[3][711:704],waved[2][711:704],waved[1][711:704],waved[0][711:704]};
        {waved[3][695:688],waved[2][695:688],waved[1][695:688],waved[0][695:688]} <= {waved[3][703:696],waved[2][703:696],waved[1][703:696],waved[0][703:696]};
        {waved[3][687:680],waved[2][687:680],waved[1][687:680],waved[0][687:680]} <= {waved[3][695:688],waved[2][695:688],waved[1][695:688],waved[0][695:688]};
        {waved[3][679:672],waved[2][679:672],waved[1][679:672],waved[0][679:672]} <= {waved[3][687:680],waved[2][687:680],waved[1][687:680],waved[0][687:680]};
        {waved[3][671:664],waved[2][671:664],waved[1][671:664],waved[0][671:664]} <= {waved[3][679:672],waved[2][679:672],waved[1][679:672],waved[0][679:672]};
        {waved[3][663:656],waved[2][663:656],waved[1][663:656],waved[0][663:656]} <= {waved[3][671:664],waved[2][671:664],waved[1][671:664],waved[0][671:664]};
        {waved[3][655:648],waved[2][655:648],waved[1][655:648],waved[0][655:648]} <= {waved[3][663:656],waved[2][663:656],waved[1][663:656],waved[0][663:656]};
        {waved[3][647:640],waved[2][647:640],waved[1][647:640],waved[0][647:640]} <= {waved[3][655:648],waved[2][655:648],waved[1][655:648],waved[0][655:648]};
        {waved[3][639:632],waved[2][639:632],waved[1][639:632],waved[0][639:632]} <= {waved[3][647:640],waved[2][647:640],waved[1][647:640],waved[0][647:640]};
        {waved[3][631:624],waved[2][631:624],waved[1][631:624],waved[0][631:624]} <= {waved[3][639:632],waved[2][639:632],waved[1][639:632],waved[0][639:632]};
        {waved[3][623:616],waved[2][623:616],waved[1][623:616],waved[0][623:616]} <= {waved[3][631:624],waved[2][631:624],waved[1][631:624],waved[0][631:624]};
        {waved[3][615:608],waved[2][615:608],waved[1][615:608],waved[0][615:608]} <= {waved[3][623:616],waved[2][623:616],waved[1][623:616],waved[0][623:616]};
        {waved[3][607:600],waved[2][607:600],waved[1][607:600],waved[0][607:600]} <= {waved[3][615:608],waved[2][615:608],waved[1][615:608],waved[0][615:608]};
        {waved[3][599:592],waved[2][599:592],waved[1][599:592],waved[0][599:592]} <= {waved[3][607:600],waved[2][607:600],waved[1][607:600],waved[0][607:600]};
        {waved[3][591:584],waved[2][591:584],waved[1][591:584],waved[0][591:584]} <= {waved[3][599:592],waved[2][599:592],waved[1][599:592],waved[0][599:592]};
        {waved[3][583:576],waved[2][583:576],waved[1][583:576],waved[0][583:576]} <= {waved[3][591:584],waved[2][591:584],waved[1][591:584],waved[0][591:584]};
        {waved[3][575:568],waved[2][575:568],waved[1][575:568],waved[0][575:568]} <= {waved[3][583:576],waved[2][583:576],waved[1][583:576],waved[0][583:576]};
        {waved[3][567:560],waved[2][567:560],waved[1][567:560],waved[0][567:560]} <= {waved[3][575:568],waved[2][575:568],waved[1][575:568],waved[0][575:568]};
        {waved[3][559:552],waved[2][559:552],waved[1][559:552],waved[0][559:552]} <= {waved[3][567:560],waved[2][567:560],waved[1][567:560],waved[0][567:560]};
        {waved[3][551:544],waved[2][551:544],waved[1][551:544],waved[0][551:544]} <= {waved[3][559:552],waved[2][559:552],waved[1][559:552],waved[0][559:552]};
        {waved[3][543:536],waved[2][543:536],waved[1][543:536],waved[0][543:536]} <= {waved[3][551:544],waved[2][551:544],waved[1][551:544],waved[0][551:544]};
        {waved[3][535:528],waved[2][535:528],waved[1][535:528],waved[0][535:528]} <= {waved[3][543:536],waved[2][543:536],waved[1][543:536],waved[0][543:536]};
        {waved[3][527:520],waved[2][527:520],waved[1][527:520],waved[0][527:520]} <= {waved[3][535:528],waved[2][535:528],waved[1][535:528],waved[0][535:528]};
        {waved[3][519:512],waved[2][519:512],waved[1][519:512],waved[0][519:512]} <= {waved[3][527:520],waved[2][527:520],waved[1][527:520],waved[0][527:520]};
        {waved[3][511:504],waved[2][511:504],waved[1][511:504],waved[0][511:504]} <= {waved[3][519:512],waved[2][519:512],waved[1][519:512],waved[0][519:512]};
        {waved[3][503:496],waved[2][503:496],waved[1][503:496],waved[0][503:496]} <= {waved[3][511:504],waved[2][511:504],waved[1][511:504],waved[0][511:504]};
        {waved[3][495:488],waved[2][495:488],waved[1][495:488],waved[0][495:488]} <= {waved[3][503:496],waved[2][503:496],waved[1][503:496],waved[0][503:496]};
        {waved[3][487:480],waved[2][487:480],waved[1][487:480],waved[0][487:480]} <= {waved[3][495:488],waved[2][495:488],waved[1][495:488],waved[0][495:488]};
        {waved[3][479:472],waved[2][479:472],waved[1][479:472],waved[0][479:472]} <= {waved[3][487:480],waved[2][487:480],waved[1][487:480],waved[0][487:480]};
        {waved[3][471:464],waved[2][471:464],waved[1][471:464],waved[0][471:464]} <= {waved[3][479:472],waved[2][479:472],waved[1][479:472],waved[0][479:472]};
        {waved[3][463:456],waved[2][463:456],waved[1][463:456],waved[0][463:456]} <= {waved[3][471:464],waved[2][471:464],waved[1][471:464],waved[0][471:464]};
        {waved[3][455:448],waved[2][455:448],waved[1][455:448],waved[0][455:448]} <= {waved[3][463:456],waved[2][463:456],waved[1][463:456],waved[0][463:456]};
        {waved[3][447:440],waved[2][447:440],waved[1][447:440],waved[0][447:440]} <= {waved[3][455:448],waved[2][455:448],waved[1][455:448],waved[0][455:448]};
        {waved[3][439:432],waved[2][439:432],waved[1][439:432],waved[0][439:432]} <= {waved[3][447:440],waved[2][447:440],waved[1][447:440],waved[0][447:440]};
        {waved[3][431:424],waved[2][431:424],waved[1][431:424],waved[0][431:424]} <= {waved[3][439:432],waved[2][439:432],waved[1][439:432],waved[0][439:432]};
        {waved[3][423:416],waved[2][423:416],waved[1][423:416],waved[0][423:416]} <= {waved[3][431:424],waved[2][431:424],waved[1][431:424],waved[0][431:424]};
        {waved[3][415:408],waved[2][415:408],waved[1][415:408],waved[0][415:408]} <= {waved[3][423:416],waved[2][423:416],waved[1][423:416],waved[0][423:416]};
        {waved[3][407:400],waved[2][407:400],waved[1][407:400],waved[0][407:400]} <= {waved[3][415:408],waved[2][415:408],waved[1][415:408],waved[0][415:408]};
        {waved[3][399:392],waved[2][399:392],waved[1][399:392],waved[0][399:392]} <= {waved[3][407:400],waved[2][407:400],waved[1][407:400],waved[0][407:400]};
        {waved[3][391:384],waved[2][391:384],waved[1][391:384],waved[0][391:384]} <= {waved[3][399:392],waved[2][399:392],waved[1][399:392],waved[0][399:392]};
        {waved[3][383:376],waved[2][383:376],waved[1][383:376],waved[0][383:376]} <= {waved[3][391:384],waved[2][391:384],waved[1][391:384],waved[0][391:384]};
        {waved[3][375:368],waved[2][375:368],waved[1][375:368],waved[0][375:368]} <= {waved[3][383:376],waved[2][383:376],waved[1][383:376],waved[0][383:376]};
        {waved[3][367:360],waved[2][367:360],waved[1][367:360],waved[0][367:360]} <= {waved[3][375:368],waved[2][375:368],waved[1][375:368],waved[0][375:368]};
        {waved[3][359:352],waved[2][359:352],waved[1][359:352],waved[0][359:352]} <= {waved[3][367:360],waved[2][367:360],waved[1][367:360],waved[0][367:360]};
        {waved[3][351:344],waved[2][351:344],waved[1][351:344],waved[0][351:344]} <= {waved[3][359:352],waved[2][359:352],waved[1][359:352],waved[0][359:352]};
        {waved[3][343:336],waved[2][343:336],waved[1][343:336],waved[0][343:336]} <= {waved[3][351:344],waved[2][351:344],waved[1][351:344],waved[0][351:344]};
        {waved[3][335:328],waved[2][335:328],waved[1][335:328],waved[0][335:328]} <= {waved[3][343:336],waved[2][343:336],waved[1][343:336],waved[0][343:336]};
        {waved[3][327:320],waved[2][327:320],waved[1][327:320],waved[0][327:320]} <= {waved[3][335:328],waved[2][335:328],waved[1][335:328],waved[0][335:328]};
        {waved[3][319:312],waved[2][319:312],waved[1][319:312],waved[0][319:312]} <= {waved[3][327:320],waved[2][327:320],waved[1][327:320],waved[0][327:320]};
        {waved[3][311:304],waved[2][311:304],waved[1][311:304],waved[0][311:304]} <= {waved[3][319:312],waved[2][319:312],waved[1][319:312],waved[0][319:312]};
        {waved[3][303:296],waved[2][303:296],waved[1][303:296],waved[0][303:296]} <= {waved[3][311:304],waved[2][311:304],waved[1][311:304],waved[0][311:304]};
        {waved[3][295:288],waved[2][295:288],waved[1][295:288],waved[0][295:288]} <= {waved[3][303:296],waved[2][303:296],waved[1][303:296],waved[0][303:296]};
        {waved[3][287:280],waved[2][287:280],waved[1][287:280],waved[0][287:280]} <= {waved[3][295:288],waved[2][295:288],waved[1][295:288],waved[0][295:288]};
        {waved[3][279:272],waved[2][279:272],waved[1][279:272],waved[0][279:272]} <= {waved[3][287:280],waved[2][287:280],waved[1][287:280],waved[0][287:280]};
        {waved[3][271:264],waved[2][271:264],waved[1][271:264],waved[0][271:264]} <= {waved[3][279:272],waved[2][279:272],waved[1][279:272],waved[0][279:272]};
        {waved[3][263:256],waved[2][263:256],waved[1][263:256],waved[0][263:256]} <= {waved[3][271:264],waved[2][271:264],waved[1][271:264],waved[0][271:264]};
        {waved[3][255:248],waved[2][255:248],waved[1][255:248],waved[0][255:248]} <= {waved[3][263:256],waved[2][263:256],waved[1][263:256],waved[0][263:256]};
        {waved[3][247:240],waved[2][247:240],waved[1][247:240],waved[0][247:240]} <= {waved[3][255:248],waved[2][255:248],waved[1][255:248],waved[0][255:248]};
        {waved[3][239:232],waved[2][239:232],waved[1][239:232],waved[0][239:232]} <= {waved[3][247:240],waved[2][247:240],waved[1][247:240],waved[0][247:240]};
        {waved[3][231:224],waved[2][231:224],waved[1][231:224],waved[0][231:224]} <= {waved[3][239:232],waved[2][239:232],waved[1][239:232],waved[0][239:232]};
        {waved[3][223:216],waved[2][223:216],waved[1][223:216],waved[0][223:216]} <= {waved[3][231:224],waved[2][231:224],waved[1][231:224],waved[0][231:224]};
        {waved[3][215:208],waved[2][215:208],waved[1][215:208],waved[0][215:208]} <= {waved[3][223:216],waved[2][223:216],waved[1][223:216],waved[0][223:216]};
        {waved[3][207:200],waved[2][207:200],waved[1][207:200],waved[0][207:200]} <= {waved[3][215:208],waved[2][215:208],waved[1][215:208],waved[0][215:208]};
        {waved[3][199:192],waved[2][199:192],waved[1][199:192],waved[0][199:192]} <= {waved[3][207:200],waved[2][207:200],waved[1][207:200],waved[0][207:200]};
        {waved[3][191:184],waved[2][191:184],waved[1][191:184],waved[0][191:184]} <= {waved[3][199:192],waved[2][199:192],waved[1][199:192],waved[0][199:192]};
        {waved[3][183:176],waved[2][183:176],waved[1][183:176],waved[0][183:176]} <= {waved[3][191:184],waved[2][191:184],waved[1][191:184],waved[0][191:184]};
        {waved[3][175:168],waved[2][175:168],waved[1][175:168],waved[0][175:168]} <= {waved[3][183:176],waved[2][183:176],waved[1][183:176],waved[0][183:176]};
        {waved[3][167:160],waved[2][167:160],waved[1][167:160],waved[0][167:160]} <= {waved[3][175:168],waved[2][175:168],waved[1][175:168],waved[0][175:168]};
        {waved[3][159:152],waved[2][159:152],waved[1][159:152],waved[0][159:152]} <= {waved[3][167:160],waved[2][167:160],waved[1][167:160],waved[0][167:160]};
        {waved[3][151:144],waved[2][151:144],waved[1][151:144],waved[0][151:144]} <= {waved[3][159:152],waved[2][159:152],waved[1][159:152],waved[0][159:152]};
        {waved[3][143:136],waved[2][143:136],waved[1][143:136],waved[0][143:136]} <= {waved[3][151:144],waved[2][151:144],waved[1][151:144],waved[0][151:144]};
        {waved[3][135:128],waved[2][135:128],waved[1][135:128],waved[0][135:128]} <= {waved[3][143:136],waved[2][143:136],waved[1][143:136],waved[0][143:136]};
        {waved[3][127:120],waved[2][127:120],waved[1][127:120],waved[0][127:120]} <= {waved[3][135:128],waved[2][135:128],waved[1][135:128],waved[0][135:128]};
        {waved[3][119:112],waved[2][119:112],waved[1][119:112],waved[0][119:112]} <= {waved[3][127:120],waved[2][127:120],waved[1][127:120],waved[0][127:120]};
        {waved[3][111:104],waved[2][111:104],waved[1][111:104],waved[0][111:104]} <= {waved[3][119:112],waved[2][119:112],waved[1][119:112],waved[0][119:112]};
        {waved[3][103:96],waved[2][103:96],waved[1][103:96],waved[0][103:96]} <= {waved[3][111:104],waved[2][111:104],waved[1][111:104],waved[0][111:104]};
        {waved[3][95:88],waved[2][95:88],waved[1][95:88],waved[0][95:88]} <= {waved[3][103:96],waved[2][103:96],waved[1][103:96],waved[0][103:96]};
        {waved[3][87:80],waved[2][87:80],waved[1][87:80],waved[0][87:80]} <= {waved[3][95:88],waved[2][95:88],waved[1][95:88],waved[0][95:88]};
        {waved[3][79:72],waved[2][79:72],waved[1][79:72],waved[0][79:72]} <= {waved[3][87:80],waved[2][87:80],waved[1][87:80],waved[0][87:80]};
        {waved[3][71:64],waved[2][71:64],waved[1][71:64],waved[0][71:64]} <= {waved[3][79:72],waved[2][79:72],waved[1][79:72],waved[0][79:72]};
        {waved[3][63:56],waved[2][63:56],waved[1][63:56],waved[0][63:56]} <= {waved[3][71:64],waved[2][71:64],waved[1][71:64],waved[0][71:64]};
        {waved[3][55:48],waved[2][55:48],waved[1][55:48],waved[0][55:48]} <= {waved[3][63:56],waved[2][63:56],waved[1][63:56],waved[0][63:56]};
        {waved[3][47:40],waved[2][47:40],waved[1][47:40],waved[0][47:40]} <= {waved[3][55:48],waved[2][55:48],waved[1][55:48],waved[0][55:48]};
        {waved[3][39:32],waved[2][39:32],waved[1][39:32],waved[0][39:32]} <= {waved[3][47:40],waved[2][47:40],waved[1][47:40],waved[0][47:40]};
        {waved[3][31:24],waved[2][31:24],waved[1][31:24],waved[0][31:24]} <= {waved[3][39:32],waved[2][39:32],waved[1][39:32],waved[0][39:32]};
        {waved[3][23:16],waved[2][23:16],waved[1][23:16],waved[0][23:16]} <= {waved[3][31:24],waved[2][31:24],waved[1][31:24],waved[0][31:24]};
        {waved[3][15:8],waved[2][15:8],waved[1][15:8],waved[0][15:8]} <= {waved[3][23:16],waved[2][23:16],waved[1][23:16],waved[0][23:16]};
        {waved[3][7:0],waved[2][7:0],waved[1][7:0],waved[0][7:0]} <= {waved[3][15:8],waved[2][15:8],waved[1][15:8],waved[0][15:8]};
    end
end


endmodule