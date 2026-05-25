`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 09:04:03 AM
// Design Name: 
// Module Name: top_uart_mac_protocol
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


module top_uart_mac_protocol #(
        parameter DEFAULT_BAURATE_DIVIDENT = 8'hd0
    )
    (
    CLK100MHZ,
    btn,
    led,
    uart_rxd_out,
    uart_txd_in,
    sw
    );
    input CLK100MHZ, uart_txd_in;
    input [1:0] btn;
    input [3:0] sw;

    output uart_rxd_out;
    output [3:0] led;
    
    // mac_unit
    wire [15:0] mac_out;
    wire mac_error;
    
    // wire clk_i = CLK100MHZ, rst_i = btn[0];
    wire [64:0] commander_input_data_bus_o;
    wire [16:0] commander_output_data_bus_i = {mac_error, mac_out};
    top_cbuff_v2 #(
        .DEFAULT_BAURATE_DIVIDENT(DEFAULT_BAURATE_DIVIDENT)
    ) top_cbuff_v2_inst (
        .CLK100MHZ(CLK100MHZ),
        .btn(btn),
        .led(led),
        .uart_rxd_out(uart_rxd_out),
        .uart_txd_in(uart_txd_in),
        .sw(sw),
        .commander_input_data_bus_o(commander_input_data_bus_o),
        .commander_output_data_bus_i(commander_output_data_bus_i)
    );

    mac_unit mac_unit_inst (
        // .in_a(commander_input_data_bus_o[15:0]),
        // .in_b(commander_input_data_bus_o[31:16]),
        // .in_c(commander_input_data_bus_o[47:32]),
        .in_a({commander_input_data_bus_o[15:8], commander_input_data_bus_o[7:0]}),
        .in_b({commander_input_data_bus_o[31:24], commander_input_data_bus_o[23:16]}),
        .in_c({commander_input_data_bus_o[47:40], commander_input_data_bus_o[39:32]}),
        
        .mode(commander_input_data_bus_o[64:64]),
        .mac_out(mac_out),
        .error(mac_error)
    );
endmodule
