// ============================================================================
// File: tb.v (Testbench GarbleChip - Chip Merah Putih Peruri)
// Sesuai dengan format resmi contoh Peruri Sandbox (tb_lampu_lalu_lintas)
// ============================================================================

`timescale 1ns / 1ps

module tb;
  reg          clk = 0;
  reg          rst_n = 0;
  reg          cmd_valid = 0;
  reg  [7:0]   cmd_opcode = 0;
  reg  [7:0]   cmd_wire_out = 0;
  reg  [7:0]   cmd_wire_in1 = 0;
  reg  [7:0]   cmd_wire_in2 = 0;
  reg  [31:0]  cmd_gate_id = 0;
  reg  [127:0] cmd_data_t0 = 0;
  reg  [127:0] cmd_data_t1 = 0;

  wire         cmd_ready;
  wire         status_busy;
  wire         status_done;
  wire         status_match;
  wire [31:0]  total_cycles;

  garblechip_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .cmd_valid(cmd_valid),
    .cmd_ready(cmd_ready),
    .cmd_opcode(cmd_opcode),
    .cmd_wire_out(cmd_wire_out),
    .cmd_wire_in1(cmd_wire_in1),
    .cmd_wire_in2(cmd_wire_in2),
    .cmd_gate_id(cmd_gate_id),
    .cmd_data_t0(cmd_data_t0),
    .cmd_data_t1(cmd_data_t1),
    .status_busy(status_busy),
    .status_done(status_done),
    .status_match(status_match),
    .total_cycles(total_cycles)
  );

  always #10 clk = ~clk;

  initial begin
    #40 rst_n = 1;

    // 1. Muat Label Input Kawat 0
    #20;
    cmd_opcode   = 8'h01;
    cmd_wire_out = 8'd0;
    cmd_data_t0  = 128'h0123456789ABCDEF0123456789ABCDE0;
    cmd_valid    = 1;
    #20 cmd_valid = 0;

    // 2. Muat Label Input Kawat 1
    #20;
    cmd_opcode   = 8'h01;
    cmd_wire_out = 8'd1;
    cmd_data_t0  = 128'hFEDCBA9876543210FEDCBA9876543211;
    cmd_valid    = 1;
    #20 cmd_valid = 0;

    // 3. Evaluasi Free-XOR: Kawat 2 = Kawat 0 ^ Kawat 1 (0 siklus latensi)
    #20;
    cmd_opcode   = 8'h02;
    cmd_wire_out = 8'd2;
    cmd_wire_in1 = 8'd0;
    cmd_wire_in2 = 8'd1;
    cmd_valid    = 1;
    #20 cmd_valid = 0;

    // 4. Selesaikan & Verifikasi Match
    #20;
    cmd_opcode   = 8'hFF;
    cmd_wire_out = 8'd2;
    cmd_data_t0  = 128'h0123456789ABCDEF0123456789ABCDE0 ^ 128'hFEDCBA9876543210FEDCBA9876543211;
    cmd_valid    = 1;
    #20 cmd_valid = 0;

    #200;
    $finish;
  end
endmodule
