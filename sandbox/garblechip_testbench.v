`timescale 1ns / 1ps

module testbench_sandbox;
    reg          clk;
    reg          rst_n;
    reg          cmd_valid;
    wire         cmd_ready;
    wire         status_busy;
    wire         status_done;
    wire         status_match;
    wire [31:0]  total_cycles;

    reg  [7:0]   cmd_opcode;
    reg  [7:0]   cmd_wire_out;
    reg  [7:0]   cmd_wire_in1;
    reg  [7:0]   cmd_wire_in2;
    reg  [31:0]  cmd_gate_id;
    reg  [127:0] cmd_data_t0;
    reg  [127:0] cmd_data_t1;

    // Instansiasi Top Core GarbleChip
    garblechip_top dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .cmd_valid    (cmd_valid),
        .cmd_ready    (cmd_ready),
        .cmd_opcode   (cmd_opcode),
        .cmd_wire_out (cmd_wire_out),
        .cmd_wire_in1 (cmd_wire_in1),
        .cmd_wire_in2 (cmd_wire_in2),
        .cmd_gate_id  (cmd_gate_id),
        .cmd_data_t0  (cmd_data_t0),
        .cmd_data_t1  (cmd_data_t1),
        .status_busy  (status_busy),
        .status_done  (status_done),
        .status_match (status_match),
        .total_cycles (total_cycles)
    );

    // Generator Clock 50 MHz (periode 20 ns)
    always #10 clk = ~clk;

    // Task input instruksi (blocking assignment legal di semua parser)
    task send_cmd;
        input [7:0]   op;
        input [7:0]   w_out;
        input [7:0]   in1;
        input [7:0]   in2;
        input [31:0]  gid;
        input [127:0] t0;
        input [127:0] t1;
        begin
            @(posedge clk);
            while (!cmd_ready) @(posedge clk);
            cmd_opcode   = op;
            cmd_wire_out = w_out;
            cmd_wire_in1 = in1;
            cmd_wire_in2 = in2;
            cmd_gate_id  = gid;
            cmd_data_t0  = t0;
            cmd_data_t1  = t1;
            cmd_valid    = 1'b1;
            @(posedge clk);
            cmd_valid    = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("simulasi.vcd");
        $dumpvars(0, testbench_sandbox);

        clk       = 0;
        rst_n     = 0;
        cmd_valid = 0;
        cmd_opcode   = 0;
        cmd_wire_out = 0;
        cmd_wire_in1 = 0;
        cmd_wire_in2 = 0;
        cmd_gate_id  = 0;
        cmd_data_t0  = 0;
        cmd_data_t1  = 0;

        #40;
        rst_n = 1;
        #20;

        $display("\n=======================================================");
        $display("   UJI COBA MANDIRI GARBLECHIP SANDBOX PERURI          ");
        $display("=======================================================");

        // 1. Muat kawat input 0 dan 1
        $display("[LANGKAH 1] Memuat Wire Label Input...");
        send_cmd(8'h01, 8'd0, 8'd0, 8'd0, 32'd0, 128'h0123456789ABCDEF0123456789ABCDE0, 128'd0);
        send_cmd(8'h01, 8'd1, 8'd0, 8'd0, 32'd0, 128'hFEDCBA9876543210FEDCBA9876543211, 128'd0);

        // 2. Evaluasi Free-XOR (Kawat 0 ^ Kawat 1 -> Kawat 2)
        $display("[LANGKAH 2] Evaluasi Free-XOR (0-cycle logic)...");
        send_cmd(8'h02, 8'd2, 8'd0, 8'd1, 32'd0, 128'd0, 128'd0);

        // 3. Selesaikan dan Verifikasi
        send_cmd(8'hFF, 8'd2, 8'd0, 8'd0, 32'd0, (128'h0123456789ABCDEF0123456789ABCDE0 ^ 128'hFEDCBA9876543210FEDCBA9876543211), 128'd0);

        while (!status_done) @(posedge clk);
        #1;

        $display("Status Selesai! Hasil Match: %b (Ekspektasi: 1)", status_match);
        $display("Total Siklus Clock: %0d", total_cycles);
        if (status_match === 1'b1) begin
            $display(">>> HASIL: PASSED! Hardware Accelerator Sukses! <<<");
        end else begin
            $display(">>> HASIL: FAILED! <<<");
        end
        $display("=======================================================\n");

        $finish;
    end

endmodule
