`timescale 1ps / 1ps
`include "../imports/rtl/uart_regs_defs.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/13/2026 11:18:30 AM
// Design Name: 
// Module Name: top
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


module top(
    CLK100MHZ,
    btn,
    led,
    uart_rxd_out,
    uart_txd_in,
    sw
    );
    input CLK100MHZ, uart_txd_in;
    input [0:0] btn;
    input [3:0] sw;

    output uart_rxd_out;
    output [1:0] led;

    wire clk_i = CLK100MHZ, rst_i = btn[0];
    
    //
    localparam PHASE_STATE_LENGTH = 3'd2;
    localparam PHASE_MAX_CNT_LENGTH = 3'd4;
    localparam PHASE_STAGE_LENGTH = 2'd2;

    localparam PHASE_STATE_BIT_NUM_INIT = 1'b0;
    localparam PHASE_STATE_BIT_NUM_GET_CONFIG_STATUS = 1'b1;
    localparam PHASE_STATE_BIT_NUM_GET_UART_STATUS = 2'd2;
    localparam PHASE_STATE_BIT_NUM_READ_UART_DATA = 2'd3;

    reg [PHASE_STATE_LENGTH-1:0] phase_state_cnt;

    always @(
        posedge clk_i or posedge rst_i
    ) begin
        if (rst_i) begin
            phase_state_cnt <= 1'b0;
        end
        else if (phase_stage == PHASE_STAGE_END) begin
            if (phase_state_cnt == PHASE_STATE_BIT_NUM_READ_UART_DATA)
                phase_state_cnt <= PHASE_STATE_BIT_NUM_GET_UART_STATUS;
            else
                phase_state_cnt <= phase_state_cnt + 1'b1;
        end
    end
    
    reg [PHASE_STAGE_LENGTH:0] phase_stage;

    localparam PHASE_STAGE_INIT = 1'b0;
    localparam PHASE_STAGE_TRIGGER = 1'b1;
    localparam PHASE_STAGE_END = 2'd2;

    always @(
        posedge clk_i or posedge rst_i
    ) begin
        if (rst_i || (phase_stage == PHASE_STAGE_END)) begin
            phase_stage <= PHASE_STAGE_INIT;
        end else if (phase_stage == PHASE_STAGE_INIT) begin
            phase_stage <= PHASE_STAGE_TRIGGER;
        end else if ((phase_stage == PHASE_STAGE_TRIGGER) && phase_is_end[phase_state_cnt]) begin
            phase_stage <= PHASE_STAGE_END;
        end
    end
    
    wire phase_cnt_start_to_count = (phase_stage == PHASE_STAGE_TRIGGER);
    reg [PHASE_MAX_CNT_LENGTH-1:0] phase_cnt;
    always @(
        posedge clk_i or posedge rst_i
    ) begin
        if (rst_i || (phase_stage == PHASE_STAGE_INIT))
            phase_cnt <= 1'b0;
        else if (phase_cnt_start_to_count)
            phase_cnt <= phase_cnt + 1'b1;  
    end

    //
    // reg [0:0] phase_is_start;
    reg [((2**PHASE_STATE_LENGTH)-1):0] phase_is_end;

    //
    reg we_i, stb_i;
    reg [7:0] addr_i;
    reg [31:0] data_i;
    reg [19:0] default_conf_reg;
    wire ack_o;
    wire [31:0] data_o;
    reg uart_rx_status;

    wire [19:0] DEFAULT_UART_CFG = {4'he,8'b0, {8'hd0 + sw[3:0]}}; // stop bit = 1, divisor = 0xd0 + sw[3:0]
    
    wire is_ack_o_or_cnt_full = ack_o || ((phase_cnt + 1'b1) == 1'b0);

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            stb_i <= 1'b0;
            we_i <= 1'b0;
            addr_i <= 8'b0;
            data_i <= 32'b0;
            phase_is_end <= {(2**PHASE_STATE_LENGTH){1'b0}};
            default_conf_reg <= 20'b0;
        end
        else if (phase_stage == PHASE_STAGE_INIT) begin
            phase_is_end[phase_state_cnt] <= 1'b0;
        end
        else if (phase_stage == PHASE_STAGE_TRIGGER) begin
            if (phase_state_cnt == PHASE_STATE_BIT_NUM_INIT) begin
                if (phase_cnt == 1'b0) begin
                    // phase_is_start[PHASE_STATE_BIT_NUM_INIT] <= 1'b1;
                    we_i <= 1'b1;
                    stb_i <= 1'b1;
                    addr_i <= `UART_CFG;
                    data_i = {12'b0, DEFAULT_UART_CFG};
                end else if (is_ack_o_or_cnt_full) begin
                    phase_is_end[PHASE_STATE_BIT_NUM_INIT] <= 1'b1;
                    we_i <= 1'b0;
                    stb_i <= 1'b0;
                end
            end
            else if (phase_state_cnt == PHASE_STATE_BIT_NUM_GET_CONFIG_STATUS) begin
                if (phase_cnt == 1'b0) begin
                    // phase_is_end[PHASE_STATE_BIT_NUM_GET_CONFIG_STATUS] <= 1'b0;
                    stb_i <= 1'b1;
                    addr_i <= `UART_CFG;
                    we_i <= 1'b0;
                end
                else if (is_ack_o_or_cnt_full) begin
                    default_conf_reg <= ack_o ? data_o[19:0] : default_conf_reg;
                    phase_is_end[PHASE_STATE_BIT_NUM_GET_CONFIG_STATUS] <= 1'b1;
                    stb_i <= 1'b0;
                end
            end
            else if (phase_state_cnt == PHASE_STATE_BIT_NUM_GET_UART_STATUS) begin
                if (phase_cnt == 1'b0) begin
                    stb_i <= 1'b1;
                    addr_i <= `UART_USR;
                    we_i <= 1'b0;
                end
                else if (is_ack_o_or_cnt_full) begin
                    uart_rx_status <= uart_rx_status + data_o[0];
                    phase_is_end[PHASE_STATE_BIT_NUM_GET_UART_STATUS] <= 1'b1;
                    stb_i <= 1'b0;
                end
            end
            else if (phase_state_cnt == PHASE_STATE_BIT_NUM_READ_UART_DATA) begin
                if (phase_cnt == 1'b0) begin
                    stb_i <= 1'b1;
                    addr_i <= `UART_UDR;
                    we_i <= 1'b0;
                end
                else if (is_ack_o_or_cnt_full) begin
                    // uart_rx_status = data_o[0];
                    phase_is_end[PHASE_STATE_BIT_NUM_READ_UART_DATA] <= 1'b1;
                    stb_i <= 1'b0;
                end
            end
        end
    end
    
    // reg uart_rx_status_toggle;
    // always @(uart_rx_status) begin
    //     uart_rx_status_toggle <= ~uart_rx_status_toggle;
    // end

    wire is_default_config_ok = default_conf_reg == DEFAULT_UART_CFG;
    assign led = {uart_rx_status, is_default_config_ok};
    
    uart_wb #(
        .UART_DIVISOR_W(10),
        .UART_DIVISOR_DEFAULT(1),
        .UART_STOP_BITS_DEFAULT(0)
    ) uart_inst (
        .clk_i(clk_i), // Connect clock
        .rst_i(rst_i), // Connect reset
        .intr_o(), // Connect interrupt output
        .tx_o(uart_rxd_out), // Connect UART TX output
        .rx_i(uart_txd_in), // Connect UART RX input
        .addr_i(addr_i), // Connect Wishbone address input
        .data_o(data_o), // Connect Wishbone data output
        .data_i(data_i), // Connect Wishbone data input
        .we_i(we_i), // Connect Wishbone write enable
        .stb_i(stb_i), // Connect Wishbone strobe
        .ack_o(ack_o)  // Connect Wishbone acknowledge output
    );
endmodule
