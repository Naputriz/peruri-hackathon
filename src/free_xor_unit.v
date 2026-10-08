// ============================================================================
// File: src/free_xor_unit.v
// Module: free_xor_unit
// Description: Free-XOR Evaluation Unit (Kolesnikov & Schneider, 2008)
//              Evaluates XOR gates with 0-cycle combinational logic (128-bit)
//              100% Universal Verilog (Verilog-1995, 2001, 2005, SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps

module free_xor_unit (
    label_a,
    label_b,
    label_out
);
    input  [127:0] label_a;
    input  [127:0] label_b;
    output [127:0] label_out;

    // Free-XOR: W_c = W_a ^ W_b purely combinational without cryptographic hash cost
    assign label_out = label_a ^ label_b;

endmodule
