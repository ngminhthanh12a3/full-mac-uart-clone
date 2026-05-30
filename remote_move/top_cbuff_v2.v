`timescale 1ns / 1ps
`include "../imports/rtl/uart_regs_defs.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/15/2026 04:13:35 AM
// Design Name: 
// Module Name: top_cbuff_v2
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


module top_cbuff_v2 #(
    parameter DEFAULT_BAURATE_DIVIDENT = 8'hd0
) (
    CLK100MHZ,
    btn,
    led,
    uart_rxd_out,
    uart_txd_in,
    sw,
    //
    commander_output_data_bus_i,
    commander_input_data_bus_o,
    db_uart_tx_shift_reg_q
    );
    input CLK100MHZ, uart_txd_in;
    input [1:0] btn;
    input [3:0] sw;

    output uart_rxd_out;
    output [3:0] led;
    output [7:0] db_uart_tx_shift_reg_q;

    wire clk_i = CLK100MHZ, rst_i = btn[0];

    //
    reg [7:0] top_uart_addr_i;
    reg [31:0] top_uart_data_i;
    reg top_uart_we_i;
    reg top_uart_stb_i;

    //
    wire [7:0] uart_loop_addr_i;
    wire [31:0] uart_loop_data_i;
    wire uart_loop_we_i;
    wire uart_loop_stb_i;

    //
    wire is_default_config_ok;
    wire uart_inst_clk_i = clk_i;
    wire uart_inst_rst_i = rst_i;
    // wire uart_inst_intr_o = ;
    wire uart_inst_tx_o;
    assign uart_rxd_out = uart_inst_tx_o;
    wire uart_inst_rx_i = is_self_test_ok ? uart_txd_in : 1'b1;
    wire uart_inst_ack_o;
    wire [31:0] uart_inst_data_o;
    wire [7:0] uart_inst_addr_i = is_default_config_ok ? top_uart_addr_i : uart_loop_addr_i;
    wire [31:0] uart_inst_data_i = is_default_config_ok ? top_uart_data_i : uart_loop_data_i;
    wire uart_inst_we_i = is_default_config_ok ? (top_uart_we_i && top_uart_addr_i == `UART_UDR) : uart_loop_we_i;
    wire uart_inst_stb_i = is_default_config_ok ? top_uart_stb_i : uart_loop_stb_i;
    wire uart_inst_uart_tx_busy_o;

    // read tx data from fifo
    reg uart_tx_fifo_rd_cplt, uart_tx_fifo_rd_wait_for_cplt;
    
    // uart_tx_fifo
    reg [7:0] uart_tx_fifo_wdata_i;
    reg uart_tx_fifo_wr_en_i, uart_tx_fifo_rd_en_i;
    wire uart_tx_fifo_full_o, uart_tx_fifo_empty_o;
    wire [7:0] uart_tx_fifo_rdata_o;

    //
    // reg [7:0] uart_tx_fifo_wdata_i;
    reg uart_tx_fifo_wr_cplt;
    
    // 
    // controller_inst
    reg [7:0] controller_inst_data_i;
    reg controller_inst_we_i, controller_inst_data_in_cplt;
    wire controller_inst_finish_o, controller_inst_error_o;
    wire [7:0] controller_inst_cmd, controller_inst_data_len_i;
    wire controller_inst_ack_data_rd_i;
    
    reg commander_inst_tx_mem_rd_cplt;
    reg [7:0] commander_inst_tx_mem_data_reg;
    
    uart_loop_cbuff #(
        .DEFAULT_BAURATE_DIVIDENT(DEFAULT_BAURATE_DIVIDENT)
    ) uart_loop_cbuff_inst (
        .CLK100MHZ(CLK100MHZ),
        .btn(btn),
        .sw(sw),
        // .led(led),
        .is_default_config_ok_o(is_default_config_ok),
        .uart_pin_ack_o(uart_inst_ack_o),
        .uart_pin_stb_i(uart_loop_stb_i),
        .uart_pin_we_i(uart_loop_we_i),
        .uart_pin_addr_i(uart_loop_addr_i),
        .uart_pin_data_i(uart_loop_data_i),
        .uart_pin_data_o(uart_inst_data_o)
    );

    uart_wb #(
        .UART_DIVISOR_W(8),
        .UART_DIVISOR_DEFAULT(1),
        .UART_STOP_BITS_DEFAULT(0)
    ) uart_inst (
        .clk_i(uart_inst_clk_i), // Connect clock
        .rst_i(uart_inst_rst_i), // Connect reset
        .intr_o(), // Connect interrupt output
        .tx_o(uart_inst_tx_o), // Connect UART TX output
        .rx_i(uart_inst_rx_i), // Connect UART RX input
        .addr_i(uart_inst_addr_i), // Connect Wishbone address input
        .data_o(uart_inst_data_o), // Connect Wishbone data output
        .data_i(uart_inst_data_i), // Connect Wishbone data input
        .we_i(uart_inst_we_i), // Connect Wishbone write enable
        .stb_i(uart_inst_stb_i), // Connect Wishbone strobe
        .ack_o(uart_inst_ack_o),  // Connect Wishbone acknowledge output
        .uart_tx_busy_o(uart_inst_uart_tx_busy_o),
        .db_uart_tx_shift_reg_q(db_uart_tx_shift_reg_q)
    );

    // get uart status
    reg top_uart_rx_status, top_uart_rx_data_ready, top_uart_wr_handle, top_uart_tx_busy_status;

    reg [7:0] top_uart_rx_data;
    wire top_uart_wr_handle_wire = (~top_uart_wr_handle & uart_tx_fifo_rd_cplt) & (~uart_inst_data_o[2]);
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            top_uart_addr_i <= `UART_USR;
            top_uart_data_i <= 32'b0;
            top_uart_we_i <= 1'b0;
            top_uart_stb_i <= 1'b1;

            top_uart_rx_status <= 1'b0;
            top_uart_rx_data_ready <= 1'b0;
            top_uart_wr_handle <= 1'b0;
            top_uart_tx_busy_status <= 1'b0;
            // top_uart_usr_wait_for_read_tx_busy <= 1'b0;

        end
        else if (is_default_config_ok)  begin
            if (top_uart_rx_data_ready && top_uart_addr_i == `UART_USR) begin
                top_uart_rx_data_ready <= 1'b0;
                // top_uart_addr_i <= `UART_USR;
            end
            else if (uart_inst_ack_o) begin
                if (top_uart_addr_i == `UART_UDR && top_uart_wr_handle) begin
                    top_uart_addr_i <= `UART_USR;
                    top_uart_we_i <= 1'b0;
                end
                else if (top_uart_addr_i == `UART_USR) begin
                    top_uart_rx_status <= uart_inst_data_o[0];
                    top_uart_tx_busy_status <= uart_inst_data_o[2];

                    top_uart_wr_handle <= top_uart_wr_handle_wire;
                    // top_uart_usr_wait_for_read_tx_busy = top_uart_usr_wait_for_read_tx_busy ? 1'b0 : 
                    //     top_uart_wr_handle ? 1'b1 : 1'b0;

                    if (uart_inst_data_o[0] && ~top_uart_wr_handle_wire) begin
                        top_uart_addr_i <= `UART_UDR;
                    end
                    // else if (~uart_inst_data_o[2] && top_uart_wr_handle && ~top_uart_we_i) begin
                    else if (top_uart_wr_handle_wire) begin
                        top_uart_addr_i <= `UART_UDR;
                        top_uart_we_i <= 1'b1;
                        top_uart_data_i <= {24'b0, uart_tx_fifo_rdata_o_reg};
                        
                    end
                end
                else if ((top_uart_addr_i == `UART_UDR) && (~top_uart_we_i) && top_uart_rx_status && ~top_uart_rx_data_ready) begin
                    top_uart_rx_data = uart_inst_data_o[7:0];
                    top_uart_rx_status <= 1'b0;
                    top_uart_addr_i <= `UART_USR;
                    top_uart_rx_data_ready <= 1'b1;
                end
            end
        end
    end

    //
    reg [7:0] uart_rx_fifo_wdata_i;
    reg uart_rx_fifo_wr_en_i, uart_rx_fifo_rd_en_i;
    wire uart_rx_fifo_full_o, uart_rx_fifo_empty_o;
    wire [7:0] uart_rx_fifo_rdata_o;

    //
    reg uart_rx_fifo_wr_cplt;

    fifo #(
        .WIDTH(8),
        .DEPTH(16)
        ) uart_rx_fifo (
            .clk_i(clk_i),
            .rst_n_i(~rst_i),
            .wdata_i(uart_rx_fifo_wdata_i),
            .wr_en_i(uart_rx_fifo_wr_en_i),
            .full_o(uart_rx_fifo_full_o),
            .rdata_o(uart_rx_fifo_rdata_o),
            .rd_en_i(uart_rx_fifo_rd_en_i),
            .empty_o(uart_rx_fifo_empty_o)
        );

    // rx ff fifo write control
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            uart_rx_fifo_wdata_i <= 8'b0;
            uart_rx_fifo_wr_en_i <= 1'b0;
            uart_rx_fifo_wr_cplt <= 1'b0;
        end
        // else if (is_default_config_ok) begin
        else if ((self_test_start || top_uart_rx_data_ready) && ~uart_rx_fifo_wr_cplt && ~uart_tx_fifo_full_o) begin
            if (self_test_start) begin
                uart_rx_fifo_wdata_i <= self_test_rx_fifo_data;
            end
            else begin
                uart_rx_fifo_wdata_i <= top_uart_rx_data;
            end
            uart_rx_fifo_wr_en_i <= 1'b1;
            uart_rx_fifo_wr_cplt <= 1'b1;
        end
        else if (uart_rx_fifo_wr_cplt) begin
            uart_rx_fifo_wr_en_i <= 1'b0;
            uart_rx_fifo_wr_cplt <= 1'b0;
        end
        // end
    end

    //
    // fifo read control
    reg [7:0] uart_rx_fifo_data_o;
    reg uart_rx_fifo_rd_cplt;
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            uart_rx_fifo_rd_en_i <= 1'b0;
            uart_rx_fifo_rd_cplt <= 1'b0;
        end
        else if (~uart_rx_fifo_empty_o && ~uart_rx_fifo_rd_cplt && ~controller_inst_data_in_cplt) begin
            uart_rx_fifo_rd_en_i <= 1'b1;
            uart_rx_fifo_data_o <= uart_rx_fifo_rdata_o;
            uart_rx_fifo_rd_cplt <= 1'b1;
        end
        else if (uart_rx_fifo_rd_cplt) begin
            uart_rx_fifo_rd_en_i <= 1'b0;
            uart_rx_fifo_rd_cplt <= 1'b0;
        end
    end

    //
    // uart_tx_fifo

    fifo #(
        .WIDTH(8),
        .DEPTH(16)
        ) uart_tx_fifo (
            .clk_i(clk_i),
            .rst_n_i(~rst_i),
            .wdata_i(uart_tx_fifo_wdata_i),
            .wr_en_i(uart_tx_fifo_wr_en_i),
            .full_o(uart_tx_fifo_full_o),
            .rdata_o(uart_tx_fifo_rdata_o),
            .rd_en_i(uart_tx_fifo_rd_en_i),
            .empty_o(uart_tx_fifo_empty_o)
        );

    // tx ff fifo write control
    always @(posedge clk_i or posedge rst_i) begin
    // always @(clk_i or rst_i) begin
        if (rst_i) begin
            uart_tx_fifo_wdata_i <= 8'b0;
            uart_tx_fifo_wr_en_i <= 1'b0;
            uart_tx_fifo_wr_cplt <= 1'b0;
        end
        else if (is_default_config_ok) begin
            if (uart_tx_fifo_wr_cplt) begin
                uart_tx_fifo_wr_en_i <= 1'b0;
                uart_tx_fifo_wr_cplt <= 1'b0;
            end
            else if (commander_inst_tx_mem_rd_cplt && ~uart_tx_fifo_wr_cplt && ~uart_tx_fifo_full_o) begin
                uart_tx_fifo_wdata_i <= commander_inst_tx_mem_data_reg;
                uart_tx_fifo_wr_en_i <= 1'b1;
                uart_tx_fifo_wr_cplt <= 1'b1;
            end
        end
    end

    //
    // read tx data from fifo
    reg [7:0] uart_tx_fifo_rdata_o_reg;
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            uart_tx_fifo_rd_en_i <= 1'b0;
            uart_tx_fifo_rd_cplt <= 1'b0;
            uart_tx_fifo_rd_wait_for_cplt <= 1'b0;
            uart_tx_fifo_rdata_o_reg <= 1'b0;
        end else if (~uart_tx_fifo_empty_o && ~uart_tx_fifo_rd_cplt) begin
            uart_tx_fifo_rd_en_i <= 1'b1;
            uart_tx_fifo_rd_cplt <= 1'b1;
            uart_tx_fifo_rdata_o_reg <= uart_tx_fifo_rdata_o;
        end else if (uart_tx_fifo_rd_cplt) begin
            uart_tx_fifo_rd_en_i <= 1'b0;
            if ((top_uart_addr_i == `UART_UDR && top_uart_wr_handle)) begin
                uart_tx_fifo_rd_cplt <= 1'b0;
            end
            // if (~uart_tx_fifo_rd_wait_for_cplt && top_uart_usr_wait_for_read_tx_busy) begin
            //     uart_tx_fifo_rd_wait_for_cplt <= 1'b1;
            // end
            // else if (uart_tx_fifo_rd_wait_for_cplt && ~top_uart_usr_wait_for_read_tx_busy) begin
            //     uart_tx_fifo_rd_cplt <= 1'b0;
            //     uart_tx_fifo_rd_wait_for_cplt <= 1'b0;
            // end
        end
    end

    //
    
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            controller_inst_we_i <= 1'b0;
            controller_inst_data_i <= 8'b0;
            controller_inst_data_in_cplt <= 1'b0;
        end
        else if (controller_inst_data_in_cplt) begin
            // if (controller_inst_ack_o)
                controller_inst_we_i <= 1'b0;
            
            // if (~uart_rx_fifo_rd_cplt) begin
                controller_inst_data_in_cplt <= 1'b0;
            // end 
        end
        else if (uart_rx_fifo_rd_cplt && ~controller_inst_data_in_cplt) begin
            controller_inst_we_i <= 1'b1;
            controller_inst_data_i <= uart_rx_fifo_data_o;
            controller_inst_data_in_cplt <= 1'b1;
        end
    end

    reg commander_inst_tx_mem_rd_e_i;
    wire [7:0] controller_inst_data_mem_o, controller_inst_data_addr_i;
    controller controller_inst (
        .clk_i(clk_i),
        .rst_i(rst_i | btn[1]),
        .data_i(controller_inst_data_i),
        .we_i(controller_inst_we_i),
        .cmd(controller_inst_cmd),
        .data_len_o(controller_inst_data_len_i),
        .finish_o(controller_inst_finish_o),
        .error_o(controller_inst_error_o),
        .ack_data_rd_i(controller_inst_ack_data_rd_i),
        .data_mem_addr_i(controller_inst_data_addr_i),
        .data_mem_o(controller_inst_data_mem_o)
    );

    wire commander_inst_tx_mem_empty_o;
    wire [7:0] commander_inst_tx_mem_data_o;
    output [64:0] commander_input_data_bus_o;
    input [16:0] commander_output_data_bus_i;
    wire commander_inst_busy_o;
    commander commander_inst (
        .clk_i(clk_i),
        .rst_i(rst_i | btn[1]),
        .exec_trigger_i(controller_inst_finish_o),
        .cmd_i(controller_inst_cmd),
        .data_len_i(controller_inst_data_len_i),
        .data_rd_i(controller_inst_data_mem_o),
        .tx_mem_rd_e_i(commander_inst_tx_mem_rd_e_i),
        // .data_rd_e_o(),
        .busy_o(commander_inst_busy_o),
        .ack_data_rd_o(controller_inst_ack_data_rd_i),
        .output_data_bus_i(commander_output_data_bus_i),
        .data_rd_addr_o(controller_inst_data_addr_i),
        
        .tx_mem_empty_o(commander_inst_tx_mem_empty_o),
        .tx_mem_data_o(commander_inst_tx_mem_data_o),
        .input_data_bus_o(commander_input_data_bus_o)
    );

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            commander_inst_tx_mem_rd_cplt <= 1'b0;
            commander_inst_tx_mem_data_reg <= 8'b0;
            commander_inst_tx_mem_rd_e_i <= 1'b0;
        end
        else if (~commander_inst_tx_mem_rd_cplt && ~commander_inst_tx_mem_empty_o && ~uart_tx_fifo_full_o) begin
            commander_inst_tx_mem_rd_cplt <= 1'b1;
            commander_inst_tx_mem_data_reg <= commander_inst_tx_mem_data_o;
            commander_inst_tx_mem_rd_e_i <= 1'b1;
        end
        else if (commander_inst_tx_mem_rd_cplt) begin
            commander_inst_tx_mem_rd_cplt <= ~uart_tx_fifo_wr_cplt;
            commander_inst_tx_mem_rd_e_i <= 1'b0;
        end
    end

    // reg self_test_enable;
    // always @(posedge clk_i or posedge rst_i) begin
    //     if (rst_i) begin
    //         self_test_enable <= 1'b0;
    //     end
    //     else if (btn[2]) begin
    //         self_test_enable <= 1'b1;
    //     end
    // end

    //

    integer ii;
    genvar jj;

    reg [2:0] self_test_test_status;
    reg [0:0] self_test_all_success_status[0:9];
    wire [9:0] self_test_all_success_status_flatten;
    for (jj = 0; jj < 10; jj=jj+1) begin
        assign self_test_all_success_status_flatten[jj] = self_test_all_success_status[jj];
    end
    wire is_self_test_ok = (&self_test_all_success_status_flatten);
    // wire is_self_test_ok = self_test_all_success_status_flatten[0];

    reg self_test_start;
    reg [7:0] self_test_rx_fifo_data;

    //
    wire [15:0] self_test_input_data_a[0:9];
    assign self_test_input_data_a[0] = 16'b0011100010100110;
    assign self_test_input_data_a[1] = 16'b1011001100011110;
    assign self_test_input_data_a[2] = 16'b1011101101001011;
    assign self_test_input_data_a[3] = 16'b1011101111011010;
    assign self_test_input_data_a[4] = 16'b1011101010011110;
    assign self_test_input_data_a[5] = 16'b1011000110110010;
    assign self_test_input_data_a[6] = 16'b0011100010111100;
    assign self_test_input_data_a[7] = 16'b1010100000001011;
    assign self_test_input_data_a[8] = 16'b0011100110111011;
    assign self_test_input_data_a[9] = 16'b0010110011001000;

    wire [15:0] self_test_input_data_b[0:9];
    assign self_test_input_data_b[0] = 16'b0011000111110000;
    assign self_test_input_data_b[1] = 16'b1011100000111101;
    assign self_test_input_data_b[2] = 16'b0011100100101010;
    assign self_test_input_data_b[3] = 16'b0010001000010001;
    assign self_test_input_data_b[4] = 16'b1011011000110000;
    assign self_test_input_data_b[5] = 16'b1001110111110111;
    assign self_test_input_data_b[6] = 16'b0011000111001111;
    assign self_test_input_data_b[7] = 16'b1011011111010001;
    assign self_test_input_data_b[8] = 16'b1011001010110001;
    assign self_test_input_data_b[9] = 16'b0011010011010100;

    wire [15:0] self_test_input_data_c[0:9];
    assign self_test_input_data_c[0] = 16'b0011100110010000;
    assign self_test_input_data_c[1] = 16'b0011010111000101;
    assign self_test_input_data_c[2] = 16'b1010111111010101;
    assign self_test_input_data_c[3] = 16'b0011101100100100;
    assign self_test_input_data_c[4] = 16'b1011100110011100;
    assign self_test_input_data_c[5] = 16'b1011011011011010;
    assign self_test_input_data_c[6] = 16'b1011101111110100;
    assign self_test_input_data_c[7] = 16'b1011100101101111;
    assign self_test_input_data_c[8] = 16'b1011001111111000;
    assign self_test_input_data_c[9] = 16'b1011100110000111;

    wire [15:0] self_test_output_ref [0:9];
    assign self_test_output_ref[0] = 16'b0011101001101101;
    assign self_test_output_ref[1] = 16'b0011011110101000;
    assign self_test_output_ref[2] = 16'b1011100110110000;
    assign self_test_output_ref[3] = 16'b0011101100001100;
    assign self_test_output_ref[4] = 16'b1011011000011010;
    assign self_test_output_ref[5] = 16'b1011011011010110;
    assign self_test_output_ref[6] = 16'b1011101100011000;
    assign self_test_output_ref[7] = 16'b1011100101001111;
    assign self_test_output_ref[8] = 16'b1011011001100001;
    assign self_test_output_ref[9] = 16'b1011100101011001;

    reg [3:0] self_test_testcase_cnt, self_test_txbyte_cnt;
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            // is_self_test_ok <= 1'b0;
            self_test_rx_fifo_data <= 1'b0;
            self_test_txbyte_cnt <= 1'b0;
            self_test_start <= 1'b0;
        end
        else if (~uart_rx_fifo_wr_cplt && ~is_self_test_ok && ~uart_tx_fifo_full_o) begin
            if (is_default_config_ok && ~self_test_start && ~(|self_test_test_status)) begin
                self_test_start <= 1'b1;

                // self_test_testcase_cnt <= 1'b1;
                self_test_txbyte_cnt <= 4'd1;
                self_test_rx_fifo_data <= 8'hab;
            end
            else if (self_test_txbyte_cnt == 4'd1) begin
                self_test_txbyte_cnt <= 4'd2;
                self_test_rx_fifo_data <= 8'hcd;
            end
            else if (self_test_txbyte_cnt == 4'd2) begin
                self_test_txbyte_cnt <= 4'd3;
                self_test_rx_fifo_data <= 8'h1;
            end
            else if (self_test_txbyte_cnt == 4'd3) begin
                self_test_txbyte_cnt <= 4'd4;
                self_test_rx_fifo_data <= 8'h9;
            end
            //
            else if (self_test_txbyte_cnt == 4'd4) begin
                self_test_txbyte_cnt <= 4'd5;
                self_test_rx_fifo_data <= self_test_input_data_a[self_test_testcase_cnt][15:8];
            end
            else if (self_test_txbyte_cnt == 4'd5) begin
                self_test_txbyte_cnt <= 4'd6;
                self_test_rx_fifo_data <= self_test_input_data_a[self_test_testcase_cnt][7:0];
            end
            else if (self_test_txbyte_cnt == 4'd6) begin
                self_test_txbyte_cnt <= 4'd7;
                self_test_rx_fifo_data <= self_test_input_data_b[self_test_testcase_cnt][15:8];
            end
            else if (self_test_txbyte_cnt == 4'd7) begin
                self_test_txbyte_cnt <= 4'd8;
                self_test_rx_fifo_data <= self_test_input_data_b[self_test_testcase_cnt][7:0];
            end
            else if (self_test_txbyte_cnt == 4'd8) begin
                self_test_txbyte_cnt <= 4'd9;
                self_test_rx_fifo_data <= self_test_input_data_c[self_test_testcase_cnt][15:8];
            end
            else if (self_test_txbyte_cnt == 4'd9) begin
                self_test_txbyte_cnt <= 4'd10;
                self_test_rx_fifo_data <= self_test_input_data_c[self_test_testcase_cnt][7:0];
            end
            else if (self_test_txbyte_cnt == 4'd10) begin
                self_test_txbyte_cnt <= 4'd11;
                self_test_rx_fifo_data <= self_test_output_ref[self_test_testcase_cnt][15:8];
            end
            else if (self_test_txbyte_cnt == 4'd11) begin
                self_test_txbyte_cnt <= 4'd12;
                self_test_rx_fifo_data <= self_test_output_ref[self_test_testcase_cnt][7:0];
            end
            else if (self_test_txbyte_cnt == 4'd12) begin
                self_test_txbyte_cnt <= 4'd13;
                self_test_rx_fifo_data <= 1'b1;
            end
            else if (self_test_txbyte_cnt == 4'd13) begin
                self_test_txbyte_cnt <= 4'd14;
                self_test_rx_fifo_data <= 8'hab;
            end
            else if (self_test_txbyte_cnt == 4'd14) begin
                self_test_txbyte_cnt <= 4'd15;
                self_test_rx_fifo_data <= 8'hcd;
            end
            else if (self_test_txbyte_cnt == 4'd15) begin
                self_test_txbyte_cnt <= 4'd0;
                // is_self_test_ok <= 1'b1;
                self_test_start <= 1'b0;
            end
        end
    end

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            self_test_testcase_cnt <= 1'b0;
        end
        else if (self_test_testcase_cnt == 4'd10) begin
            self_test_testcase_cnt <= 1'b0;
        end
        else if (self_test_test_status == 4'd4) begin
            self_test_testcase_cnt <= self_test_testcase_cnt + 1'b1;
        end
    end

    //

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            self_test_test_status <= 1'b0;
            // self_test_all_success_status <= 1'b0;
            for (ii = 0;ii < 10 ; ii=ii+1) begin
                self_test_all_success_status[ii] <= 1'b0;
            end
        end
        else if (self_test_start && ~(|self_test_test_status)) begin // test_status wait for start end
            self_test_test_status <= 4'd1;
        end
        else if (self_test_test_status == 4'd1 && ~self_test_start) begin // test_status wait for busy signal from commander
            self_test_test_status <= 4'd2;
        end
        else if (self_test_test_status == 4'd2 && commander_inst_busy_o) begin // test_status wait for busy signal from commander
            self_test_test_status <= 4'd3;
        end
        else if (self_test_test_status == 4'd3 && ~commander_inst_busy_o) begin // test_status detects busy signal is end
            self_test_test_status <= 4'd4;
        end
        else if (self_test_test_status == 4'd4) begin
            self_test_test_status <= 4'd0;
            self_test_all_success_status[self_test_testcase_cnt] <= (self_test_output_ref[self_test_testcase_cnt] == commander_output_data_bus_i[15:0] || 
            self_test_output_ref[self_test_testcase_cnt] == (1'b1 + commander_output_data_bus_i[15:0]) || 
            self_test_output_ref[self_test_testcase_cnt] == (commander_output_data_bus_i[15:0] - 1'b1));
        end
    end

    reg commander_busy_toggle;
    always @(posedge commander_inst_busy_o or posedge rst_i) begin
        if (rst_i) begin
            commander_busy_toggle <= 1'b0;
        end
        else
            commander_busy_toggle <= ~commander_inst_busy_o;
    end

    reg controller_inst_finish_o_toggle;
    always @(posedge controller_inst_finish_o or posedge rst_i) begin
        if (rst_i) begin
            controller_inst_finish_o_toggle <= 1'b0;
        end
        else
            controller_inst_finish_o_toggle <= ~controller_inst_finish_o_toggle;
    end
    
    assign led = {controller_inst_finish_o_toggle, commander_busy_toggle, is_self_test_ok, is_default_config_ok};

endmodule
