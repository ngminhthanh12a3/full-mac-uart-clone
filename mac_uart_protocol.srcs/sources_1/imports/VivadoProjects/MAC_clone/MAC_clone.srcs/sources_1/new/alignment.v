`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/07/2026 05:53:33 AM
// Design Name: 
// Module Name: alignment
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module alignment (
	input  [14:0] bigger, 
	input  [14:0] smaller,
	output [10:0] aligned_small
	);

	wire c1;
	wire [4:0] bigger_exponent, smaller_exponent,shift_bits;

	assign bigger_exponent  = bigger  [14:10];
	assign smaller_exponent = smaller [14:10];
	assign aligned_small    = ({1'b1,smaller[9:0]} >> shift_bits);

	cla_nbit #(.n(5)) u1(bigger_exponent,~smaller_exponent+1'b1,1'b0,shift_bits,c1);

endmodule

