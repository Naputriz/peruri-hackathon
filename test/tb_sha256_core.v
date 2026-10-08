// ============================================================================
// File: tb_sha256_core.v
// Module: tb_sha256_core
// Description: Testbench Verilog mandiri untuk sha256_iterative_core
//              Memverifikasi kesesuaian terhadap NIST standard vectors
// ============================================================================

`timescale 1ns / 1ps

module tb_sha256_core;

    reg          clk;
    reg          rst_n;
    reg          start;
    reg  [511:0] block_512;
    wire         ready;
    wire         done;
    wire [255:0] digest;

    // Instansiasi Device Under Test (DUT)
    sha256_iterative_core dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .block_512 (block_512),
        .ready     (ready),
        .done      (done),
        .digest    (digest)
    );

    // Generator Clock 50 MHz (periode 20 ns)
    always #10 clk = ~clk;

    // Expected NIST digest untuk "abc"
    // Padded 512-bit block untuk "abc":
    // "abc" (3 bytes = 0x61, 0x62, 0x63) + 0x80 + 52 bytes zero + 64-bit length (24 bits = 0x18)
    localparam [511:0] BLOCK_ABC = {
        8'h61, 8'h62, 8'h63, 8'h80,
        416'd0,
        64'd24
    };
    localparam [255:0] EXPECTED_ABC = 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;

    // Expected digest untuk empty string ""
    localparam [511:0] BLOCK_EMPTY = {
        8'h80,
        440'd0,
        64'd0
    };
    localparam [255:0] EXPECTED_EMPTY = 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;

    integer errors;

    initial begin
        $dumpfile("simulasi.vcd");
        $dumpvars(0, tb_sha256_core);

        clk = 0;
        rst_n = 0;
        start = 0;
        block_512 = 0;
        errors = 0;

        $display("\n=======================================================");
        $display("   STARTING TESTBENCH: sha256_iterative_core");
        $display("=======================================================");

        // Reset pulsa
        #40;
        rst_n = 1;
        #20;

        // ----------------------------------------------------
        // TEST CASE 1: NIST Vector "abc"
        // ----------------------------------------------------
        $display("[TEST 1] Testing NIST vector 'abc'...");
        @(posedge clk);
        block_512 = BLOCK_ABC;
        start = 1;
        @(posedge clk);
        start = 0;

        // Tunggu sinyal done
        @(posedge done);
        #1;
        if (digest === EXPECTED_ABC) begin
            $display("[TEST 1] PASSED! Digest MATCH: %064x", digest);
        end else begin
            $display("[TEST 1] FAILED!");
            $display("  Expected: %064x", EXPECTED_ABC);
            $display("  Got:      %064x", digest);
            errors = errors + 1;
        end

        #40;

        // ----------------------------------------------------
        // TEST CASE 2: NIST Vector Empty String ""
        // ----------------------------------------------------
        $display("[TEST 2] Testing NIST vector empty string ''...");
        @(posedge clk);
        block_512 = BLOCK_EMPTY;
        start = 1;
        @(posedge clk);
        start = 0;

        @(posedge done);
        #1;
        if (digest === EXPECTED_EMPTY) begin
            $display("[TEST 2] PASSED! Digest MATCH: %064x", digest);
        end else begin
            $display("[TEST 2] FAILED!");
            $display("  Expected: %064x", EXPECTED_EMPTY);
            $display("  Got:      %064x", digest);
            errors = errors + 1;
        end

        #40;
        if (errors == 0) begin
            $display("=======================================================");
            $display("   ALL SHA-256 TEST CASES PASSED SUCCESSFULLY!");
            $display("=======================================================\n");
        end else begin
            $display(">>> TESTBENCH COMPLETED WITH %0d ERRORS <<<\n", errors);
        end

        $finish;
    end

endmodule
