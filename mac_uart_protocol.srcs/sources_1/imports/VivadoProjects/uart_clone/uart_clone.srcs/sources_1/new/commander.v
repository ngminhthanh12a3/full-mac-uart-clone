`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/22/2026 02:23:44 AM
// Design Name: 
// Module Name: commander
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


module commander(
    clk_i,
    rst_i,
    exec_trigger_i,
    cmd_i,
    data_len_i,
    data_rd_i,
    //
    tx_mem_rd_e_i,
    output_data_bus_i,

    //
    data_rd_addr_o,
    busy_o,
    ack_data_rd_o,
    //
    tx_mem_empty_o,
    tx_mem_data_o,
    input_data_bus_o,
    );
    input clk_i, rst_i, exec_trigger_i, tx_mem_rd_e_i;
    input [7:0] cmd_i, data_len_i, data_rd_i;
    output reg busy_o, ack_data_rd_o;
    output reg [7:0] data_rd_addr_o;
    output tx_mem_empty_o;
    output [7:0] tx_mem_data_o;
    input [16:0] output_data_bus_i;

    // reg [7:0] tx_mem[0:255];

    reg [7:0] data_bus_out[0:255];
    output [64:0] input_data_bus_o;
    genvar ii;
    // for (ii = 2; ii < 8; ii=ii+1) begin : input_data_bus_assign
    //     assign input_data_bus_o[ii*8+7:ii*8] = data_bus_out[ii];
    // end
    assign input_data_bus_o[7:0] = data_bus_out[1];
    assign input_data_bus_o[15:8] = data_bus_out[0];
    assign input_data_bus_o[23:16] = data_bus_out[3];
    assign input_data_bus_o[31:24] = data_bus_out[2];
    assign input_data_bus_o[39:32] = data_bus_out[5];
    assign input_data_bus_o[47:40] = data_bus_out[4];
    
    assign input_data_bus_o[64] = data_bus_out[8][0];


    // assign input_data_bus_o = {data_bus_out[1], data_bus_out[0], data_bus_out[3], data_bus_out[2], data_bus_out[5], data_bus_out[4], data_bus_out[8][0]};
    

    reg interal_data_rd_ready;
    reg [7:0] resp_data_len;

    integer j;
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            data_rd_addr_o <= 1'b0;
            busy_o <= 1'b0;
            ack_data_rd_o <= 1'b0;
            interal_data_rd_ready <= 1'b0;
            // data_bus_out <= 1'b0;
            for (j = 0; j < 256; j=j+1) begin
                data_bus_out[j] <= 1'b0;
            end
            resp_data_len <= 1'b0;
        end
        else if (ack_data_rd_o) begin
            ack_data_rd_o <= 1'b0;
        end
        else if (exec_trigger_i) begin
            if (cmd_i == 1'b0) begin
                if (~busy_o) begin
                    busy_o <= 1'b1;
                    interal_data_rd_ready <= 1'b1;
                end
                else if (tx_mem_drive_data_cplt) begin
                    ack_data_rd_o <= 1'b1;
                    busy_o <= 1'b0;
                    interal_data_rd_ready <= 1'b0;
                end
            end
            else if (cmd_i == 1'b1) begin
                if (~busy_o) begin
                    data_rd_addr_o <= 1'b0;
                    busy_o <= 1'b1;
                    resp_data_len <= 8'd7;
                    // interal_data_rd_ready <= 1'b1;
                end
                else if (busy_o && ~tx_mem_drive_data_cplt && (data_rd_addr_o != data_len_i)) begin
                    data_rd_addr_o <= data_rd_addr_o + 1'b1;
                    data_bus_out[data_rd_addr_o] <= data_rd_i;
                end
                else if ((data_rd_addr_o == data_len_i) && ~interal_data_rd_ready) begin
                    interal_data_rd_ready <= 1'b1;
                end
                else if (tx_mem_drive_data_cplt) begin
                    ack_data_rd_o <= 1'b1;
                    busy_o <= 1'b0;
                    interal_data_rd_ready <= 1'b0;
                end
            end
        end
    end

    //
    // reg [7:0] tx_mem_wr_ptr, tx_mem_rd_ptr;
    reg tx_mem_wait_for_data, tx_mem_drive_data_in, tx_mem_drive_data_cplt;
    reg [9:0] tx_mem_data_cnt;

    reg [7:0] tx_fifo_wdata_i;
    // reg tx_fifo_wr_en_i;
    wire tx_fifo_full_o, tx_fifo_empty_o;
    wire [7:0] tx_fifo_rdata_o;
    
    fifo #(
        .WIDTH(8),
        .DEPTH(256)
    ) tx_fifo (
        .clk_i(clk_i),
        .rst_n_i(~rst_i),
        .wdata_i(tx_fifo_wdata_i),
        .wr_en_i(tx_mem_drive_data_in),
        .full_o(tx_fifo_full_o),
        .rdata_o(tx_fifo_rdata_o),
        .rd_en_i(tx_mem_rd_e_i),
        .empty_o(tx_fifo_empty_o)
    );

    wire [7:0] data_len_no_headers = resp_data_len + 3'd4;
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            tx_mem_wait_for_data <= 1'b0;
            tx_mem_drive_data_in <= 1'b0;
            tx_mem_drive_data_cplt <= 1'b0;
            tx_mem_data_cnt <= 10'b0;
            // tx_mem_wr_ptr <= 8'b0;
            tx_fifo_wdata_i <= 8'b0;
            // tx_fifo_wr_en_i <= 1'b0;

        end
        else if (~tx_mem_wait_for_data && exec_trigger_i && ~interal_data_rd_ready) begin
            tx_mem_wait_for_data <= 1'b1;
            tx_mem_drive_data_in <= 1'b0;
            tx_mem_data_cnt <= 10'b0;
            tx_mem_drive_data_cplt <= 1'b0;
        end
        else if (tx_mem_wait_for_data && interal_data_rd_ready) begin
            tx_mem_wait_for_data <= 1'b0;
            tx_mem_drive_data_in <= 1'b1;
        end
        else if (tx_mem_drive_data_in && ~tx_fifo_full_o) begin
            
            tx_mem_data_cnt <= tx_mem_data_cnt + 1'b1;

            if (tx_mem_data_cnt == 10'b0) begin
                tx_fifo_wdata_i <= 8'hab;
                
            end
            else if (tx_mem_data_cnt == 10'b1) begin
                tx_fifo_wdata_i <= 8'hcd;
            end
            else if (cmd_i == 8'b0) begin
                // if (tx_mem_data_cnt == 10'd2) begin
                //     tx_fifo_wdata_i <= 8'h00;
                // end
                // else if (tx_mem_data_cnt == 10'd3) begin
                //     tx_fifo_wdata_i <= 8'h01;
                // end
                // else if (tx_mem_data_cnt == 10'd4) begin
                //     tx_fifo_wdata_i <= 8'h01;
                // end
                // else if (tx_mem_data_cnt == 10'd5) begin
                //     tx_fifo_wdata_i <= 8'hab;
                // end
                // else if (tx_mem_data_cnt == 10'd6) begin
                //     tx_fifo_wdata_i <= 8'hcd;
                // end
                // else if (tx_mem_data_cnt == 10'd7) begin
                //     tx_mem_drive_data_in <= 1'b0;
                //     tx_mem_drive_data_cplt <= 1'b1;
                // end
                
                if (tx_mem_data_cnt == 10'd2) begin
                    tx_fifo_wdata_i <= 8'h01;
                end
                else if (tx_mem_data_cnt == 10'd3) begin
                    tx_fifo_wdata_i <= 8'd3;
                end
                else if (tx_mem_data_cnt == 8'd4) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    tx_fifo_wdata_i <= output_data_bus_i[7:0];
                end
                else if (tx_mem_data_cnt == 8'd5) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    tx_fifo_wdata_i <= output_data_bus_i[15:8];
                end
                else if (tx_mem_data_cnt == 8'd6) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    tx_fifo_wdata_i <= {output_data_bus_i[16], 7'b0};
                end
                else if (tx_mem_data_cnt == 8'd7) begin
                    tx_fifo_wdata_i <= 8'hab;
                end
                else if (tx_mem_data_cnt == 8'd8) begin
                    tx_fifo_wdata_i <= 8'hcd;
                end
                else if (tx_mem_data_cnt == 8'd9) begin
                    tx_mem_drive_data_in <= 1'b0;
                    tx_mem_drive_data_cplt <= 1'b1;
                end
            end
            else if (cmd_i == 8'b1) begin
                // if (tx_mem_data_cnt == 10'd2) begin
                //     tx_fifo_wdata_i <= 8'h01;
                // end
                // else if (tx_mem_data_cnt == 10'd3) begin
                //     tx_fifo_wdata_i <= resp_data_len;
                // end
                // else if (tx_mem_data_cnt == 8'd4) begin
                //     // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                //     // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                //     tx_fifo_wdata_i <= output_data_bus_i[7:0];
                // end
                // else if (tx_mem_data_cnt == 8'd5) begin
                //     // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                //     // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                //     tx_fifo_wdata_i <= output_data_bus_i[15:8];
                // end
                // else if (tx_mem_data_cnt == 8'd6) begin
                //     // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                //     // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                //     tx_fifo_wdata_i <= {output_data_bus_i[16], 7'b0};
                // end
                // else if (tx_mem_data_cnt == 8'd7) begin
                //     tx_fifo_wdata_i <= 8'hab;
                // end
                // else if (tx_mem_data_cnt == 8'd8) begin
                //     tx_fifo_wdata_i <= 8'hcd;
                // end
                // else if (tx_mem_data_cnt == 8'd9) begin
                //     tx_mem_drive_data_in <= 1'b0;
                //     tx_mem_drive_data_cplt <= 1'b1;
                // end
                if (tx_mem_data_cnt == 10'd2) begin
                    tx_fifo_wdata_i <= 8'h01;
                end
                else if (tx_mem_data_cnt == 10'd3) begin
                    tx_fifo_wdata_i <= resp_data_len;
                end
                else if (tx_mem_data_cnt == 8'd4) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    tx_fifo_wdata_i <= input_data_bus_o[7:0];
                end
                else if (tx_mem_data_cnt == 8'd5) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    tx_fifo_wdata_i <= input_data_bus_o[15:8];
                end
                else if (tx_mem_data_cnt == 8'd6) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    // tx_fifo_wdata_i <= {output_data_bus_i[16], 7'b0};
                    tx_fifo_wdata_i <= input_data_bus_o[23:16];
                end
                else if (tx_mem_data_cnt == 8'd7) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    // tx_fifo_wdata_i <= {output_data_bus_i[16], 7'b0};
                    tx_fifo_wdata_i <= input_data_bus_o[31:24];
                end
                else if (tx_mem_data_cnt == 8'd8) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    // tx_fifo_wdata_i <= {output_data_bus_i[16], 7'b0};
                    tx_fifo_wdata_i <= input_data_bus_o[39:32];
                end
                else if (tx_mem_data_cnt == 8'd9) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    // tx_fifo_wdata_i <= {output_data_bus_i[16], 7'b0};
                    tx_fifo_wdata_i <= input_data_bus_o[47:40];
                end
                else if (tx_mem_data_cnt == 8'd10) begin
                    // tx_fifo_wdata_i <= data_bus_out[tx_mem_data_cnt - 3'd4];

                    // tx_fifo_wdata_i <= input_data_bus_o[(tx_mem_data_cnt - 3'd4)*8 +: 8];
                    // tx_fifo_wdata_i <= {output_data_bus_i[16], 7'b0};
                    tx_fifo_wdata_i <= input_data_bus_o[64:64];
                end
                else if (tx_mem_data_cnt == 8'd11) begin
                    tx_fifo_wdata_i <= 8'hab;
                end
                else if (tx_mem_data_cnt == 8'd12) begin
                    tx_fifo_wdata_i <= 8'hcd;
                end
                else if (tx_mem_data_cnt == 8'd13) begin
                    tx_mem_drive_data_in <= 1'b0;
                    tx_mem_drive_data_cplt <= 1'b1;
                end
            end
        end
    end

    assign tx_mem_data_o = tx_fifo_rdata_o;
    assign tx_mem_empty_o = tx_fifo_empty_o;
endmodule
