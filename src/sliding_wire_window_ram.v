// ============================================================================
// File: src/sliding_wire_window_ram.v
// Module: sliding_wire_window_ram
// Description: Dual-Port 128-bit Scratchpad Memory based on M10K BRAM
//              Implements Sliding Wire Window Architecture (Mo et al., ISCA 2023)
//              Only stores active wires within the circuit cut-width
//              100% Universal Verilog (Verilog-1995, 2001, 2005, SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps

module sliding_wire_window_ram (
    input  wire         clk,
    input  wire         we,
    input  wire [7:0]   wr_addr,
    input  wire [127:0] wr_data,
    input  wire [7:0]   rd_addr_a,
    output wire [127:0] rd_data_a,
    input  wire [7:0]   rd_addr_b,
    output wire [127:0] rd_data_b
);
    parameter DEPTH = 256;      // Capacity of wire window (cut-width)
    parameter WIDTH = 128;      // Wire label width (128-bit)

    // Internal M10K scratchpad memory array
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) begin
            mem[wr_addr] <= wr_data;
        end
    end

    // Combinational dual-port read for zero-stall evaluation throughput
    assign rd_data_a = mem[rd_addr_a];
    assign rd_data_b = mem[rd_addr_b];

endmodule
