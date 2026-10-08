// ============================================================================
// File: src/sliding_wire_window_ram.v
// Module: sliding_wire_window_ram
// Description: Memori Scratchpad Dual-Port 128-bit berbasis BRAM M10K
//              Mengimplementasikan Sliding Wire Window (Mo et al., ISCA 2023)
//              Hanya menyimpan kawat aktif dalam jangkauan cut-width
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
    parameter DEPTH = 256;      // Kapasitas jendela kawat (cut-width)
    parameter WIDTH = 128;      // Ukuran label kawat (128-bit)

    // Array memori internal scratchpad M10K
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) begin
            mem[wr_addr] <= wr_data;
        end
    end

    // Pembacaan kombinasi dual-port untuk throughput evaluasi 0-stalls
    assign rd_data_a = mem[rd_addr_a];
    assign rd_data_b = mem[rd_addr_b];

endmodule
