// ============================================================================
// File: src/garblechip_top.v
// Module: garblechip_top
// Description: Top-Level Synthesizable IP Core GarbleChip
//              Integrates Circuit FSM Evaluator, Iterative SHA-256 Core,
//              Free-XOR Unit, and Sliding Wire Window Scratchpad RAM.
//              Target Platform: Terasic DE10-Nano (Cyclone V SoC 5CSEBA6U23I7)
// ============================================================================

`timescale 1ns / 1ps

module garblechip_top (
    input  wire         clk,
    input  wire         rst_n,

    // Command Streaming Interface
    input  wire         cmd_valid,
    output wire         cmd_ready,
    input  wire [7:0]   cmd_opcode,      // 0x01: LOAD, 0x02: XOR, 0x03: AND, 0xFF: FINISH
    input  wire [7:0]   cmd_wire_out,
    input  wire [7:0]   cmd_wire_in1,
    input  wire [7:0]   cmd_wire_in2,
    input  wire [31:0]  cmd_gate_id,
    input  wire [127:0] cmd_data_t0,
    input  wire [127:0] cmd_data_t1,

    // On-board Status & Benchmark Indicator (DE10-Nano LEDs)
    output wire         status_busy,
    output wire         status_done,
    output wire         status_match,
    output wire [31:0]  total_cycles
);

    // SHA-256 Interconnect Wires
    wire         sha_start;
    wire [511:0] sha_block;
    wire         sha_ready;
    wire         sha_done;
    wire [255:0] sha_digest;

    // Sliding Wire Window RAM Interconnect Wires
    wire         ram_we;
    wire [7:0]   ram_wr_addr;
    wire [127:0] ram_wr_data;
    wire [7:0]   ram_rd_addr_a;
    wire [127:0] ram_rd_data_a;
    wire [7:0]   ram_rd_addr_b;
    wire [127:0] ram_rd_data_b;

    // Free-XOR Interconnect Wires
    wire [127:0] xor_in_a;
    wire [127:0] xor_in_b;
    wire [127:0] xor_out;

    // 1. Sliding Wire Window Scratchpad RAM Instance (M10K BRAM)
    sliding_wire_window_ram u_wire_ram (
        .clk       (clk),
        .we        (ram_we),
        .wr_addr   (ram_wr_addr),
        .wr_data   (ram_wr_data),
        .rd_addr_a (ram_rd_addr_a),
        .rd_data_a (ram_rd_data_a),
        .rd_addr_b (ram_rd_addr_b),
        .rd_data_b (ram_rd_data_b)
    );

    // 2. Free-XOR Logic Unit Instance (0-cycle combinational)
    free_xor_unit u_xor_unit (
        .label_a   (xor_in_a),
        .label_b   (xor_in_b),
        .label_out (xor_out)
    );

    // 3. Iterative SHA-256 Core PRF Engine Instance (64 cycles)
    sha256_core_iterative u_sha256 (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (sha_start),
        .block_512 (sha_block),
        .ready     (sha_ready),
        .done      (sha_done),
        .digest    (sha_digest)
    );

    // 4. Circuit Evaluator FSM Controller Instance
    garble_gate_fsm u_fsm (
        .clk           (clk),
        .rst_n         (rst_n),
        .cmd_valid     (cmd_valid),
        .cmd_ready     (cmd_ready),
        .cmd_opcode    (cmd_opcode),
        .cmd_wire_out  (cmd_wire_out),
        .cmd_wire_in1  (cmd_wire_in1),
        .cmd_wire_in2  (cmd_wire_in2),
        .cmd_gate_id   (cmd_gate_id),
        .cmd_data_t0   (cmd_data_t0),
        .cmd_data_t1   (cmd_data_t1),
        .eval_busy     (status_busy),
        .eval_done     (status_done),
        .match_result  (status_match),
        .cycle_counter (total_cycles),
        .sha_start     (sha_start),
        .sha_block     (sha_block),
        .sha_ready     (sha_ready),
        .sha_done      (sha_done),
        .sha_digest    (sha_digest),
        .ram_we        (ram_we),
        .ram_wr_addr   (ram_wr_addr),
        .ram_wr_data   (ram_wr_data),
        .ram_rd_addr_a (ram_rd_addr_a),
        .ram_rd_data_a (ram_rd_data_a),
        .ram_rd_addr_b (ram_rd_addr_b),
        .ram_rd_data_b (ram_rd_data_b),
        .xor_in_a      (xor_in_a),
        .xor_in_b      (xor_in_b),
        .xor_out       (xor_out)
    );

endmodule
