////////////////////////////////////////////////////////////////////////////////
// Company: Linfan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: Linfan0
// Module Name: 7segments Digital Tube Driver(input with BCD code)
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    7segments Digital Tube Driver(input with BCD code)
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    7segments Digital Tube Driver(input with BCD code)
////////////////////////////////////////////////////////////////////////////////
module seg7_led_bcd(
    input        clk,
    input        rstn,
    input  [15:0] bcd,
    output [3:0] sel_t,
    output [7:0] seg_led_t    
);

//reg define
reg [7:0]  seg_led;

reg [3:0] code;
reg [3:0] ring;
reg [15:0] count;

reg [15:0] bcd_load;

assign sel_t     = ~ring_display    ;   // if use common negtive, set ~ here. Otherwise not
assign seg_led_t = ~seg_led ;           // if use common negtive, set ~ here. Otherwise not

parameter CNT_MAX = 50000000; /* f=50MHz(T=20ns) => T'=1s */
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

always@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        ring <= 4'b1110;
        count <= 32'b0;
    end else begin
        count <= count + 1;
        if(count == 16'b0) begin
            ring <= {ring[2:0],ring[3]};
        end
    end
end

always@(posedge clk_01 or negedge rstn)begin
    if(~rstn)begin
        bcd_load <= 16'b0;
    end else begin
        bcd_load <= bcd;
    end
end

wire [3:0] mask;
wire [3:0] ring_display;
assign mask = {(bcd_load[15:12] == 4'b0), (bcd_load[15:12] == 4'b0 && bcd_load[11:8] == 4'b0), 
    (bcd_load[15:12] == 4'b0 && bcd_load[11:8] == 4'b0 && bcd_load[7:4] == 4'b0), 1'b0};
assign ring_display = ~((~mask) & (~ring));

always@(*)begin
    case(ring)
        4'b1110: code = bcd_load[3:0];
        4'b1101: code = bcd_load[7:4];
        4'b1011: code = bcd_load[11:8];
        4'b0111: code = bcd_load[15:12];
        default: code = 1'b0;
    endcase
end

always@(*)begin
    case (code)
        5'd0 : seg_led <= 8'b11000000;
        5'd1 : seg_led <= 8'b11111001;
        5'd2 : seg_led <= 8'b10100100;
        5'd3 : seg_led <= 8'b10110000;
        5'd4 : seg_led <= 8'b10011001;
        5'd5 : seg_led <= 8'b10010010;
        5'd6 : seg_led <= 8'b10000010;
        5'd7 : seg_led <= 8'b11111000;
        5'd8 : seg_led <= 8'b10000000;
        5'd9 : seg_led <= 8'b10010000;
        default: seg_led <= 8'b1111_1111;
    endcase
end   
    
endmodule