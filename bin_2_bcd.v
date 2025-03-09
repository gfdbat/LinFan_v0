////////////////////////////////////////////////////////////////////////////////
// Project: LinFan
// Engineer: Gfdbat / XG
//
// Create Date: 2025-03-05 19:17
// Design Name: LinFan0
// Module Name: BIN to BCD converter
// Target Device: xc7z020clg400-2
// Tool versions: Vivado 2024.2
// Description:
//    Heat Controller 
// Dependencies:
//    None
// Revision:
//    0.0.0 - File Created
// Additional Comments:
//    Transform BIN code to BCD code
////////////////////////////////////////////////////////////////////////////////
module bin_2_bcd
#( 
	parameter	W = 8
)  					
( 
	input		[W-1 :0] 		bin,	
	output reg	[W+(W-4)/3:0]	bcd   
); 					

integer i,j;

always @(*) begin
	for(i = 0; i <= W+(W-4)/3; i = i+1) 
		bcd[i] = 0;     	// Initialization with Zeros
	bcd[W-1:0] = bin; 		// Replace the lower bits with input
	
	for(i = 0; i <= W-4; i = i+1)                       	
		for(j = 0; j <= i/3; j = j+1)                     
            if (bcd[W-i+4*j -: 4] > 4)	
				bcd[W-i+4*j -: 4] = bcd[W-i+4*j -: 4] + 4'd3; // plus 3 if > 4
end

endmodule
