// ============================================================================
// Platform: Chip Merah Putih Sandbox (chip.peruri.co.id)
// File: sha256_sandbox_package.v
// Deskripsi: Paket lengkap mandiri (Self-Contained) untuk Uji Coba Simulasi
//            dan Sintesis Core SHA-256 Baseline pada Sandbox Web Peruri.
//            Kompatibel 100% dengan Verilog-1995 / 2001 / YosysJS / Icarus
// ============================================================================

`timescale 1ns / 1ps

// ============================================================================
// 1. ROM Konstanta K (K0..K63)
// ============================================================================
module sha256_k_constants (
    input  wire [5:0]  round_idx,
    output reg  [31:0] k_out
);
    always @(*) begin
        case (round_idx)
            6'd0:  k_out = 32'h428a2f98; 6'd1:  k_out = 32'h71374491;
            6'd2:  k_out = 32'hb5c0fbcf; 6'd3:  k_out = 32'he9b5dba5;
            6'd4:  k_out = 32'h3956c25b; 6'd5:  k_out = 32'h59f111f1;
            6'd6:  k_out = 32'h923f82a4; 6'd7:  k_out = 32'hab1c5ed5;
            6'd8:  k_out = 32'hd807aa98; 6'd9:  k_out = 32'h12835b01;
            6'd10: k_out = 32'h243185be; 6'd11: k_out = 32'h550c7dc3;
            6'd12: k_out = 32'h72be5d74; 6'd13: k_out = 32'h80deb1fe;
            6'd14: k_out = 32'h9bdc06a7; 6'd15: k_out = 32'hc19bf174;
            6'd16: k_out = 32'he49b69c1; 6'd17: k_out = 32'hefbe4786;
            6'd18: k_out = 32'h0fc19dc6; 6'd19: k_out = 32'h240ca1cc;
            6'd20: k_out = 32'h2de92c6f; 6'd21: k_out = 32'h4a7484aa;
            6'd22: k_out = 32'h5cb0a9dc; 6'd23: k_out = 32'h76f988da;
            6'd24: k_out = 32'h983e5152; 6'd25: k_out = 32'ha831c66d;
            6'd26: k_out = 32'hb00327c8; 6'd27: k_out = 32'hbf597fc7;
            6'd28: k_out = 32'hc6e00bf3; 6'd29: k_out = 32'hd5a79147;
            6'd30: k_out = 32'h06ca6351; 6'd31: k_out = 32'h14292967;
            6'd32: k_out = 32'h27b70a85; 6'd33: k_out = 32'h2e1b2138;
            6'd34: k_out = 32'h4d2c6dfc; 6'd35: k_out = 32'h53380d13;
            6'd36: k_out = 32'h650a7354; 6'd37: k_out = 32'h766a0abb;
            6'd38: k_out = 32'h81c2c92e; 6'd39: k_out = 32'h92722c85;
            6'd40: k_out = 32'ha2bfe8a1; 6'd41: k_out = 32'ha81a664b;
            6'd42: k_out = 32'hc24b8b70; 6'd43: k_out = 32'hc76c51a3;
            6'd44: k_out = 32'hd192e819; 6'd45: k_out = 32'hd6990624;
            6'd46: k_out = 32'hf40e3585; 6'd47: k_out = 32'h106aa070;
            6'd48: k_out = 32'h19a4c116; 6'd49: k_out = 32'h1e376c08;
            6'd50: k_out = 32'h2748774c; 6'd51: k_out = 32'h34b0bcb5;
            6'd52: k_out = 32'h391c0cb3; 6'd53: k_out = 32'h4ed8aa4a;
            6'd54: k_out = 32'h5b9cca4f; 6'd55: k_out = 32'h682e6ff3;
            6'd56: k_out = 32'h748f82ee; 6'd57: k_out = 32'h78a5636f;
            6'd58: k_out = 32'h84c87814; 6'd59: k_out = 32'h8cc70208;
            6'd60: k_out = 32'h90befffa; 6'd61: k_out = 32'ha4506ceb;
            6'd62: k_out = 32'hbef9a3f7; 6'd63: k_out = 32'hc67178f2;
            default: k_out = 32'h00000000;
        endcase
    end
endmodule

// ============================================================================
// 2. Core SHA-256 Iteratif 64-Siklus (Synthesizable RTL)
// ============================================================================
module sha256_iterative_core (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [511:0] block_512,
    output reg          ready,
    output reg          done,
    output reg  [255:0] digest
);
    parameter [31:0] H0_INIT = 32'h6a09e667;
    parameter [31:0] H1_INIT = 32'hbb67ae85;
    parameter [31:0] H2_INIT = 32'h3c6ef372;
    parameter [31:0] H3_INIT = 32'ha54ff53a;
    parameter [31:0] H4_INIT = 32'h510e527f;
    parameter [31:0] H5_INIT = 32'h9b05688c;
    parameter [31:0] H6_INIT = 32'h1f83d9ab;
    parameter [31:0] H7_INIT = 32'h5be0cd19;

    parameter [1:0] S_IDLE     = 2'b00;
    parameter [1:0] S_ROUNDS   = 2'b01;
    parameter [1:0] S_FINALIZE = 2'b10;

    reg [1:0] state;
    reg [5:0] round_cnt;
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] w_reg [0:15];

    wire [31:0] k_cur;
    sha256_k_constants u_k (
        .round_idx(round_cnt),
        .k_out(k_cur)
    );

    wire [31:0] ch_val   = (e & f) ^ (~e & g);
    wire [31:0] maj_val  = (a & b) ^ (a & c) ^ (b & c);

    // NIST Sigma & Gamma via Bit-Slicing Murni (Zero Gate, tanpa function syntax error)
    wire [31:0] s0_val   = {a[1:0], a[31:2]} ^ {a[12:0], a[31:13]} ^ {a[21:0], a[31:22]};
    wire [31:0] s1_val   = {e[5:0], e[31:6]} ^ {e[10:0], e[31:11]} ^ {e[24:0], e[31:25]};
    wire [31:0] gam0_val = {w_reg[1][6:0], w_reg[1][31:7]} ^ {w_reg[1][17:0], w_reg[1][31:18]} ^ (w_reg[1] >> 3);
    wire [31:0] gam1_val = {w_reg[14][16:0], w_reg[14][31:17]} ^ {w_reg[14][18:0], w_reg[14][31:19]} ^ (w_reg[14] >> 10);

    wire [31:0] w_cur = w_reg[0];
    wire [31:0] w_new = w_reg[0] + gam0_val + w_reg[9] + gam1_val;

    wire [31:0] t1 = h + s1_val + ch_val + k_cur + w_cur;
    wire [31:0] t2 = s0_val + maj_val;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            ready     <= 1'b1;
            done      <= 1'b0;
            digest    <= 256'd0;
            round_cnt <= 6'd0;
            a <= 32'd0; b <= 32'd0; c <= 32'd0; d <= 32'd0;
            e <= 32'd0; f <= 32'd0; g <= 32'd0; h <= 32'd0;
            for (i = 0; i < 16; i = i + 1) w_reg[i] <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        ready     <= 1'b0;
                        state     <= S_ROUNDS;
                        round_cnt <= 6'd0;
                        a <= H0_INIT; b <= H1_INIT; c <= H2_INIT; d <= H3_INIT;
                        e <= H4_INIT; f <= H5_INIT; g <= H6_INIT; h <= H7_INIT;

                        w_reg[0]  <= block_512[511:480]; w_reg[1]  <= block_512[479:448];
                        w_reg[2]  <= block_512[447:416]; w_reg[3]  <= block_512[415:384];
                        w_reg[4]  <= block_512[383:352]; w_reg[5]  <= block_512[351:320];
                        w_reg[6]  <= block_512[319:288]; w_reg[7]  <= block_512[287:256];
                        w_reg[8]  <= block_512[255:224]; w_reg[9]  <= block_512[223:192];
                        w_reg[10] <= block_512[191:160]; w_reg[11] <= block_512[159:128];
                        w_reg[12] <= block_512[127:96];  w_reg[13] <= block_512[95:64];
                        w_reg[14] <= block_512[63:32];   w_reg[15] <= block_512[31:0];
                    end else begin
                        ready <= 1'b1;
                    end
                end

                S_ROUNDS: begin
                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + t1;
                    d <= c;
                    c <= b;
                    b <= a;
                    a <= t1 + t2;

                    for (i = 0; i < 15; i = i + 1) w_reg[i] <= w_reg[i+1];
                    w_reg[15] <= w_new;

                    if (round_cnt == 6'd63) state <= S_FINALIZE;
                    else round_cnt <= round_cnt + 6'd1;
                end

                S_FINALIZE: begin
                    digest <= {
                        (H0_INIT + a), (H1_INIT + b), (H2_INIT + c), (H3_INIT + d),
                        (H4_INIT + e), (H5_INIT + f), (H6_INIT + g), (H7_INIT + h)
                    };
                    done  <= 1'b1;
                    ready <= 1'b1;
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

// ============================================================================
// 3. Testbench Mandiri (Untuk Tab "Jalankan simulasi" & "Gelombang")
// ============================================================================
module testbench_sha256;
    reg          clk;
    reg          rst_n;
    reg          start;
    reg  [511:0] block_512;
    wire         ready;
    wire         done;
    wire [255:0] digest;

    sha256_iterative_core dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .block_512 (block_512),
        .ready     (ready),
        .done      (done),
        .digest    (digest)
    );

    always #10 clk = ~clk;

    // Vektor NIST 'abc'
    localparam [511:0] BLOCK_ABC = {8'h61, 8'h62, 8'h63, 8'h80, 416'd0, 64'd24};
    localparam [255:0] EXP_ABC   = 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;

    initial begin
        $dumpfile("simulasi.vcd");
        $dumpvars(0, testbench_sha256);

        clk = 0;
        rst_n = 0;
        start = 0;
        block_512 = 0;

        $display("\n=======================================================");
        $display("   MEMULAI SIMULASI CHIP MERAH PUTIH: SHA-256 CORE     ");
        $display("=======================================================");

        #40;
        rst_n = 1;
        #20;

        $display("[UJI 1] Menguji Vektor Standar NIST 'abc'...");
        @(posedge clk);
        block_512 = BLOCK_ABC;
        start = 1;
        @(posedge clk);
        start = 0;

        @(posedge done);
        #1;
        if (digest === EXP_ABC) begin
            $display("[UJI 1] BERHASIL! Hash Digest Match: %064x", digest);
        end else begin
            $display("[UJI 1] GAGAL! Mismatch pada output digest!");
        end

        #40;
        $display("=======================================================");
        $display("   SIMULASI SELESAI DENGAN SUKSES!                     ");
        $display("=======================================================");
        $finish;
    end
endmodule
