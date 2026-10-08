// ============================================================================
// File: tb_garblechip_top.v
// Module: tb_garblechip_top
// Description: Testbench Verilog End-to-End untuk GarbleChip Top Level
//              Menguji Evaluasi Private PIN Verification (MATCH vs MISMATCH)
// ============================================================================

`timescale 1ns / 1ps

module tb_garblechip_top;

    reg          clk;
    reg          rst_n;

    reg          cmd_valid;
    wire         cmd_ready;
    reg  [7:0]   cmd_opcode;
    reg  [7:0]   cmd_wire_out;
    reg  [7:0]   cmd_wire_in1;
    reg  [7:0]   cmd_wire_in2;
    reg  [31:0]  cmd_gate_id;
    reg  [127:0] cmd_data_t0;
    reg  [127:0] cmd_data_t1;

    wire         status_busy;
    wire         status_done;
    wire         status_match;
    wire [31:0]  total_cycles;

    // Instansiasi Device Under Test (DUT)
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

    // Clock generator 50 MHz (periode 20 ns)
    always #10 clk = ~clk;

    // Task untuk mengirim perintah 1 siklus
    task send_instruction;
        input [7:0]   op;
        input [7:0]   w_out;
        input [7:0]   w_in1;
        input [7:0]   w_in2;
        input [31:0]  gid;
        input [127:0] d_t0;
        input [127:0] d_t1;
        begin
            @(posedge clk);
            while (!cmd_ready) @(posedge clk);
            cmd_opcode   = op;
            cmd_wire_out = w_out;
            cmd_wire_in1 = w_in1;
            cmd_wire_in2 = w_in2;
            cmd_gate_id  = gid;
            cmd_data_t0  = d_t0;
            cmd_data_t1  = d_t1;
            cmd_valid    = 1'b1;
            @(posedge clk);
            cmd_valid    = 1'b0;
        end
    endtask

    // Buffer dan variabel untuk pembacaan berkas hex
    integer file_handle;
    integer scan_count;
    integer total_tests_passed;
    reg [2047:0] line_buf;
    reg [7:0]    h_op, h_wout, h_in1, h_in2;
    reg [31:0]   h_gid;
    reg [127:0]  h_t0, h_t1;

    task run_test_vector_file;
        input [255:0] filepath;
        input         expected_result;
        begin
            $display("\n>>> Memulai Pengujian File Vector: %s", filepath);
            file_handle = $fopen(filepath, "r");
            if (file_handle == 0) begin
                $display("[ERROR] Gagal membuka file: %s", filepath);
                $finish;
            end

            // Reset DUT
            rst_n = 0;
            cmd_valid = 0;
            #40;
            rst_n = 1;
            #20;

            while (!$feof(file_handle)) begin
                line_buf = "";
                scan_count = $fgets(line_buf, file_handle);
                if (scan_count > 0 && line_buf[2047:2032] != "//") begin
                    // Parse baris hex berdasarkan opcode
                    // Ambil byte pertama (opcode)
                    scan_count = $sscanf(line_buf, "%h", h_op);
                    if (scan_count == 1) begin
                        if (h_op == 8'h01) begin // LOAD_WIRE
                            scan_count = $sscanf(line_buf, "%h %h %h %h %h", h_op, h_wout, h_in1, h_in2, h_t0);
                            send_instruction(h_op, h_wout, 8'h00, 8'h00, 32'd0, h_t0, 128'd0);
                        end
                        else if (h_op == 8'h02) begin // EVAL_XOR
                            scan_count = $sscanf(line_buf, "%h %h %h %h", h_op, h_wout, h_in1, h_in2);
                            send_instruction(h_op, h_wout, h_in1, h_in2, 32'd0, 128'd0, 128'd0);
                        end
                        else if (h_op == 8'h03) begin // EVAL_AND
                            scan_count = $sscanf(line_buf, "%h %h %h %h %h %h %h", h_op, h_wout, h_in1, h_in2, h_gid, h_t0, h_t1);
                            send_instruction(h_op, h_wout, h_in1, h_in2, h_gid, h_t0, h_t1);
                        end
                        else if (h_op == 8'hFF) begin // FINISH
                            scan_count = $sscanf(line_buf, "%h %h %h %h %h", h_op, h_wout, h_in1, h_in2, h_t0);
                            send_instruction(h_op, h_wout, 8'h00, 8'h00, 32'd0, h_t0, 128'd0);
                        end
                    end
                end
            end

            $fclose(file_handle);

            // Tunggu hingga status_done aktif
            while (!status_done) @(posedge clk);
            #1;

            $display("-------------------------------------------------------");
            $display("HASIL PENGUJIAN FILE: %s", filepath);
            $display("  Total Siklus Clock: %0d siklus (%0.2f us @ 50 MHz)", total_cycles, (total_cycles * 0.020));
            $display("  Status Match Keluaran: %b (Ekspektasi: %b)", status_match, expected_result);

            if (status_match === expected_result) begin
                $display("  >>> STATUS: PASSED! Akurasi 100%% Terverifikasi! <<<");
                total_tests_passed = total_tests_passed + 1;
            end else begin
                $display("  >>> STATUS: FAILED! Mismatch hasil deteksi! <<<");
            end
            $display("-------------------------------------------------------");
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        cmd_valid = 0;
        total_tests_passed = 0;

        $display("\n=======================================================");
        $display("   TESTBENCH END-TO-END GARBLECHIP TOP ACCELERATOR   ");
        $display("   Yao's Garbled Circuit Evaluator (Cyclone V / ASIC) ");
        $display("=======================================================");

        // 1. Jalankan pengujian MATCH (PIN Alice = PIN Bob = 0x123456)
        run_test_vector_file("test/test_vector_match.hex", 1'b1);

        #100;

        // 2. Jalankan pengujian MISMATCH (PIN Alice = 0x123456, PIN Bob = 0x123457)
        run_test_vector_file("test/test_vector_mismatch.hex", 1'b0);

        #100;
        $display("\n=======================================================");
        if (total_tests_passed == 2) begin
            $display("  SELURUH UJI SKENARIO END-TO-END LOLOS SEMPURNA! (2/2)");
        end else begin
            $display("  BEBERAPA PENGUJIAN GAGAL (%0d/2)", total_tests_passed);
        end
        $display("=======================================================\n");

        $finish;
    end

endmodule
