// ============================================================================
// File: wire_label_ram.v
// Module: wire_label_ram
// Description: Scratchpad RAM 128-bit untuk menyimpan label kawat aktif
//              Dua port baca (wire_a, wire_b) dan satu port tulis (wire_out)
//              100% Universal Verilog (Verilog-1995, 2001, 2005, SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps

module wire_label_ram (
    clk,
    we,
    wr_addr,
    wr_data,
    rd_addr_a,
    rd_data_a,
    rd_addr_b,
    rd_data_b
);
    parameter ADDR_WIDTH = 8;   // 256 baris label kawat
    parameter DATA_WIDTH = 128; // 128-bit label kawat per entri

    input                  clk;
    input                  we;
    input  [ADDR_WIDTH-1:0] wr_addr;
    input  [DATA_WIDTH-1:0] wr_data;
    input  [ADDR_WIDTH-1:0] rd_addr_a;
    output [DATA_WIDTH-1:0] rd_data_a;
    input  [ADDR_WIDTH-1:0] rd_addr_b;
    output [DATA_WIDTH-1:0] rd_data_b;

    // Array memori internal scratchpad
    reg [DATA_WIDTH-1:0] mem [0:255];

    always @(posedge clk) begin
        if (we) begin
            mem[wr_addr] <= wr_data;
        end
    end

    // Asynchronous / combinational read untuk meminimalkan latency FSM
    assign rd_data_a = mem[rd_addr_a];
    assign rd_data_b = mem[rd_addr_b];

endmodule
