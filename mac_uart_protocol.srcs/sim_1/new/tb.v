`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/23/2026 12:15:13 PM
// Design Name: 
// Module Name: tb
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


module tb(

    );
    //----------------------------------------------------------------
	// Internal constant and parameter definitions.
	//----------------------------------------------------------------
	parameter CLK_HALF_PERIOD = 2;
	parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;

    reg clk;
    wire [3:0] led;
    reg uart_txd_in;
    wire uart_rxd_out;
    reg rst;
    wire [2:0] btn = {1'b1, 1'b0, rst};
    reg [3:0] sw;

    top_uart_mac_protocol #(.DEFAULT_BAURATE_DIVIDENT(8'd1)) dut(
        .CLK100MHZ(clk),
        .btn(btn),
        .led(led),
        .uart_rxd_out(uart_rxd_out),
        .uart_txd_in(uart_txd_in),
        .sw(sw)
    );

    //----------------------------------------------------------------
	// clk_gen
	//
	// Clock generator process.
	//----------------------------------------------------------------
	always
		begin : clk_gen
			#CLK_HALF_PERIOD clk = ~clk;
		end // clk_gen
    
    //----------------------------------------------------------------
	// reset_dut()
	//
	// Toggles reset to force the DUT into a well defined state.
	//----------------------------------------------------------------
	task reset_dut;
		begin
			$display("*** Toggling reset...");
			rst = 1;
			#(4 * CLK_HALF_PERIOD);
			rst = 0;
		end
	endtask // reset_dut()

    //----------------------------------------------------------------
	// init_sim()
	//
	// Initialize all counters and testbed functionality as well
	// as setting the DUT inputs to defined values.
	//----------------------------------------------------------------
	task init_sim;
		begin
			clk		= 0;
			rst		= 1;
            // btn
            uart_txd_in = 1;
            sw = 4'b0;
		end
	endtask // init_sim()

    initial begin : mac_uart_test
        $display("*** Testbench for mac_uart started.");

        init_sim();
        reset_dut();
    end
endmodule
