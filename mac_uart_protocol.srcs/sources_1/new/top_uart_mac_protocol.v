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
    MT_CLK100MHZ,
    MT_btn,
    MT_led,
    MT_uart_rxd_out,
    MT_uart_txd_in,
    MT_sw,
//    MT_db_uart_tx_shift_reg_q,
//    MT_db_uart_rx_fifo_wdata_i,
//    MT_db_uart_rx_fifo_wr_en_i,
//    MT_db_internal_rxd_i,
//    MT_db_internal_txd_o
    );
    input MT_CLK100MHZ, MT_uart_txd_in;
    input [1:0] MT_btn;
    input [3:0] MT_sw;

    output MT_uart_rxd_out;
    output [3:0] MT_led;
//    output [7:0] MT_db_uart_tx_shift_reg_q;
//    output [7:0] MT_db_uart_rx_fifo_wdata_i;
//    output MT_db_uart_rx_fifo_wr_en_i;
//    output MT_db_internal_rxd_i;
//    output MT_db_internal_txd_o;

    // mac_unit
    wire [15:0] mac_out;
    wire mac_error;
    
    // wire clk_i = MT_CLK100MHZ, rst_i = MT_btn[0];
    wire [64:0] commander_input_data_bus_o;
    wire [16:0] commander_output_data_bus_i = {mac_error, mac_out};
    top_cbuff_v2 #(
        .DEFAULT_BAURATE_DIVIDENT(DEFAULT_BAURATE_DIVIDENT)
    ) top_cbuff_v2_inst (
        .CLK100MHZ(MT_CLK100MHZ),
        .btn(MT_btn),
        .led(MT_led),
        .uart_rxd_out(MT_uart_rxd_out),
        .uart_txd_in(MT_uart_txd_in),
        .sw(MT_sw),
        .commander_input_data_bus_o(commander_input_data_bus_o),
        .commander_output_data_bus_i(commander_output_data_bus_i)
//        .db_uart_tx_shift_reg_q(MT_db_uart_tx_shift_reg_q),
//        .db_uart_rx_fifo_wdata_i(MT_db_uart_rx_fifo_wdata_i),
//        .db_uart_rx_fifo_wr_en_i(MT_db_uart_rx_fifo_wr_en_i),
//        .db_internal_rxd_i(MT_db_internal_rxd_i),
//        .db_internal_txd_o(MT_db_internal_txd_o)
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
