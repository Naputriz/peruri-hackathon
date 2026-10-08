// ============================================================================
// File: free_xor_unit.v
// Module: free_xor_unit
// Description: Unit Evaluasi Free-XOR (Kolesnikov & Schneider, 2008)
//              Mengevaluasi gerbang XOR dalam 0-cycle kombinasional (128-bit)
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

    // Free-XOR: W_c = W_a ^ W_b murni kombinasional tanpa biaya hash / crypto
    assign label_out = label_a ^ label_b;

endmodule
