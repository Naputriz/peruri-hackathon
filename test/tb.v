// ============================================================================
// File: test/tb.v (Peruri Web Simulator Sandbox Target)
// Project: GarbleChip — Hardware Cryptography Accelerator (Chip Merah Putih Peruri)
// Module: tb_garblechip (Testbench for Private PIN Circuit Evaluator)
// Syntax Standard: 100% Compliant with Official Peruri Template (tb_lampu_lalu_lintas)
// ============================================================================

module tb_garblechip;
  reg          clk = 0;
  reg          rst_n = 0;
  reg          start = 0;
  reg  [1:0]   opcode = 0;
  reg  [2:0]   dst_id = 0;
  reg  [2:0]   src1_id = 0;
  reg  [2:0]   src2_id = 0;
  reg  [31:0]  gate_id = 0;
  reg  [127:0] table_tg = 0;
  reg  [127:0] table_te = 0;
  reg  [127:0] in_data = 0;

  wire         ready;
  wire         busy;
  wire         done;
  wire         match;
  wire [127:0] out_label;
  wire [31:0]  timer;

  garblechip dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .opcode(opcode),
    .dst_id(dst_id),
    .src1_id(src1_id),
    .src2_id(src2_id),
    .gate_id(gate_id),
    .table_tg(table_tg),
    .table_te(table_te),
    .in_data(in_data),
    .ready(ready),
    .busy(busy),
    .done(done),
    .match(match),
    .out_label(out_label),
    .timer(timer)
  );

  always #5 clk = ~clk;

  initial begin
    #20 rst_n = 1;

    // STEP 1: Load User Secret PIN Input Label (Wire 0)
    #20;
    opcode   = 2'd0; // OP_LOAD
    dst_id   = 3'd0;
    in_data  = 128'h0123456789ABCDEF0123456789ABCDE0;
    start    = 1;
    #10 start = 0;
    #20;

    // STEP 2: Load Server Credential Input Label (Wire 1)
    #20;
    opcode   = 2'd0; // OP_LOAD
    dst_id   = 3'd1;
    in_data  = 128'hFEDCBA9876543210FEDCBA9876543211;
    start    = 1;
    #10 start = 0;
    #20;

    // STEP 3: Evaluate Free-XOR: Wire 2 = Wire 0 ^ Wire 1 (0-Cycle Cryptographic Latency)
    #20;
    opcode   = 2'd1; // OP_XOR (Free-XOR)
    dst_id   = 3'd2;
    src1_id  = 3'd0;
    src2_id  = 3'd1;
    start    = 1;
    #10 start = 0;
    #20;

    // STEP 4: Evaluate Garbled AND (Half-Gates Zahur with Iterative SHA-256 PRF Engine)
    #20;
    opcode   = 2'd2; // OP_AND (Half-Gates)
    dst_id   = 3'd3;
    src1_id  = 3'd0;
    src2_id  = 3'd1;
    gate_id  = 32'd1;
    table_tg = 128'hA1B2C3D4E5F60718293A4B5C6D7E8F90;
    table_te = 128'h1029384756AFBECD1029384756AFBECD;
    start    = 1;
    #10 start = 0;

    // Wait for SHA-256 evaluation to complete (~132 clock cycles = ~1320 ns)
    #1400;

    // STEP 5: Verify PIN Match Result (Wire 2 vs Expected Label)
    #20;
    opcode   = 2'd3; // OP_VERIFY
    src1_id  = 3'd2;
    in_data  = 128'h0123456789ABCDEF0123456789ABCDE0 ^ 128'hFEDCBA9876543210FEDCBA9876543211;
    start    = 1;
    #10 start = 0;
    #40;

    $display("\n=======================================================");
    $display("   GARBLECHIP HARDWARE ACCELERATOR SIMULATION RESULT   ");
    $display("   Platform: Peruri Sandbox / Terasic DE10-Nano SoC    ");
    $display("=======================================================");
    $display(" Status Ready : %b | Done : %b", ready, done);
    $display(" Status Match : %b (Expected: 1'b1 - PIN MATCH)", match);
    $display(" Total Cycles : %0d clock cycles", timer);
    if (match === 1'b1) begin
      $display(" >>> STATUS: PASSED! Private PIN Verification Succeeded! <<<");
    end else begin
      $display(" >>> STATUS: FAILED! <<<");
    end
    $display("=======================================================\n");

    #200;
    $finish;
  end
endmodule
