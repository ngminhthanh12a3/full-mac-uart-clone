`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/20/2026 04:57:53 PM
// Design Name: 
// Module Name: controller
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


module controller # (
    parameter H1 = 8'hAB,
    parameter H2 = 8'hCD,
    parameter T1 = 8'hAB,
    parameter T2 = 8'hCD,
    parameter DATA_BIT_WIDTH = 4'd8
) (
    clk_i,
    rst_i,
    data_i,
    we_i,
    cmd,
    re_i,
    ack_data_rd_i,
    data_mem_addr_i,
    data_len_o,
    finish_o,
    error_o,
    data_mem_o
    );
    input [7:0] data_i, data_mem_addr_i;
    input we_i;
    input re_i;
    input clk_i;
    input rst_i;
    input ack_data_rd_i;

    output reg finish_o, error_o;
    output reg [7:0] cmd, data_len_o;
    output [7:0] data_mem_o;
    reg [7:0] data_mem [0:2**DATA_BIT_WIDTH-1];
    reg [(DATA_BIT_WIDTH + 6)-1:0] data_in_cnt;
    wire interal_we_i = we_i & ~finish_o & ~error_o; //& ~ack_o;

    //
    // data-in block
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            data_in_cnt <= 0;
            cmd <= 0;
            data_len_o <= 0;
            error_o <= 0;
            finish_o <= 0;
        end
        else if ((finish_o & ack_data_rd_i) || error_o) begin
            data_in_cnt <= 0;
            cmd <= 0;
            data_len_o <= 0;
            error_o <= 0;
            finish_o <= 0;
        end
        else if (interal_we_i) begin
            //
            // header phase
            if (data_in_cnt == 14'b0) begin
                data_in_cnt <= (14'b1);
                error_o <= (data_i != H1);
            end
            else if (data_in_cnt == 14'b1) begin
                data_in_cnt <= (14'd2);
                error_o <= (data_i != H2);
                // finish_o <= (data_i == H2);
            end
            // // // cmd phase
            else if (data_in_cnt == 14'd2) begin
                data_in_cnt <= 14'd3;
                cmd <= data_i;
            end
            // datalen phase
            else if (data_in_cnt == 14'd3) begin
                data_in_cnt <= 14'd4;
                data_len_o <= data_i;
            end
            // data phase
            else if (data_in_cnt >= 14'd4 && data_in_cnt < (data_len_o + 14'd4)) begin
                data_in_cnt <= data_in_cnt + 1'b1;
                data_mem[data_in_cnt - 14'd4] <= data_i;
            end
            // T1, T2 phase
            else if (data_in_cnt == (data_len_o + 14'd4)) begin
                data_in_cnt <= (data_in_cnt + 14'b1);
                error_o <= (data_i != T1);
            end
            else if (data_in_cnt == (data_len_o + 14'd5)) begin
                data_in_cnt <= (data_in_cnt + 14'b1);
                error_o <= (data_i != T2);
                finish_o <= (data_i == T2);
            end
        end
        
    end

    //
    // timeout block
    reg [9:0] timeout_cnt;
    reg timeout_start;
    wire is_timeout = (&timeout_cnt);
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            timeout_cnt <= 1'b0;
            timeout_start <= 1'b0;
        end
        else if ((data_in_cnt == 0 && we_i)) begin
            timeout_cnt <= 1'b0;
            timeout_start <= 1'b1;
        end
        else if (~is_timeout && timeout_start) begin
            timeout_cnt <= timeout_cnt + 1'b1;
        end
        else if (is_timeout && finish_o) begin
            timeout_start <= 1'b0;
        end

    end

    assign data_mem_o = data_mem[data_mem_addr_i];
endmodule
