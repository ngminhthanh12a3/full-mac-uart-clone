`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/15/2026 03:22:24 AM
// Design Name: 
// Module Name: fifo
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


module fifo #(
    parameter WIDTH = 32,
    parameter DEPTH = 16
) (
    // Clock and Reset
    input             clk_i,
    input             rst_n_i,
    // Write Interface
    input [WIDTH-1:0] wdata_i,
    input             wr_en_i,
    output             full_o,
    // Read Interface
    output [WIDTH-1:0] rdata_o,
    input             rd_en_i,
    output             empty_o
);
    // Timing specification
//    timeunit 1ns; 
//    timeprecision 100ps;

    // Local parameters
    localparam ADDR_WIDTH = $clog2(DEPTH);

    // Internal signals
    reg [ADDR_WIDTH-1:0] rptr, wptr;
    wire full, empty;
    reg last_was_read;

    // Memory array
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    // Write operation
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            wptr <= 1'b0;
        end else begin
            if (wr_en_i && !full) begin
                mem[wptr] <= wdata_i;
                wptr <= wptr + 1'b1;
            end
        end
    end

    // Read operation
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            rptr <= 1'b0;
        end else begin
            if (rd_en_i && !empty) begin
                rptr <= rptr + 1'b1;
            end
        end
    end
    
    // Continuous read data assignment
    assign rdata_o = mem[rptr];

    // Last operation tracker
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            last_was_read <= 1'b1; // Initialize as empty
        end else begin
            if (rd_en_i && !empty) begin
                last_was_read <= 1'b1;
            end else if (wr_en_i && !full) begin
                last_was_read <= 1'b0;
            end
            // else maintain current state
        end
    end
    
    // Status flag generation
    assign full  = (wptr == rptr) && !last_was_read;
    assign empty = (wptr == rptr) &&  last_was_read;
    
    assign full_o  = full;
    assign empty_o = empty;
endmodule
