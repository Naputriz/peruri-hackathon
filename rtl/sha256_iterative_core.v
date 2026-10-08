// ============================================================================
// File: sha256_iterative_core.v
// Module: sha256_iterative_core
// Description: Core SHA-256 1-Blok 512-bit Iteratif 64-Siklus Hemat Area
//              Standar NIST FIPS 180-4 untuk GarbleChip PRF Engine
//              100% Universal Verilog (Verilog-1995, 2001, 2005, SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps

module sha256_iterative_core (
    clk,
    rst_n,
    start,
    block_512,
    ready,
    done,
    digest
);
    input          clk;
    input          rst_n;
    input          start;
    input  [511:0] block_512;  // 16 kata 32-bit (M0..M15, MSB first)
    output         ready;
    reg            ready;
    output         done;
    reg            done;
    output [255:0] digest;     // H0..H7 (256-bit)
    reg    [255:0] digest;

    // Initial constants H0..H7
    parameter H0_INIT = 32'h6a09e667;
    parameter H1_INIT = 32'hbb67ae85;
    parameter H2_INIT = 32'h3c6ef372;
    parameter H3_INIT = 32'ha54ff53a;
    parameter H4_INIT = 32'h510e527f;
    parameter H5_INIT = 32'h9b05688c;
    parameter H6_INIT = 32'h1f83d9ab;
    parameter H7_INIT = 32'h5be0cd19;

    // State machine
    parameter S_IDLE     = 2'd0;
    parameter S_ROUNDS   = 2'd1;
    parameter S_FINALIZE = 2'd2;

    reg [1:0] state;
    reg [5:0] round_cnt;

    // Working variables A..H
    reg [31:0] a, b, c, d, e, f, g, h;

    // Shift register array untuk Message Schedule W (16 x 32-bit)
    reg [31:0] w_reg [0:15];

    // ROM Konstanta K
    wire [31:0] k_cur;
    sha256_k_constants u_k_constants (
        .round_idx(round_cnt),
        .k_out(k_cur)
    );

    // Fungsi Logika Kombinasional NIST FIPS 180-4
    wire [31:0] ch_val   = (e & f) ^ (~e & g);
    wire [31:0] maj_val  = (a & b) ^ (a & c) ^ (b & c);

    // NIST Sigma & Gamma via Bit-Slicing Murni (Zero Gate)
    // Sigma0(a) = ROTR2(a) ^ ROTR13(a) ^ ROTR22(a)
    wire [31:0] s0_val   = {a[1:0], a[31:2]} ^ {a[12:0], a[31:13]} ^ {a[21:0], a[31:22]};

    // Sigma1(e) = ROTR6(e) ^ ROTR11(e) ^ ROTR25(e)
    wire [31:0] s1_val   = {e[5:0], e[31:6]} ^ {e[10:0], e[31:11]} ^ {e[24:0], e[31:25]};

    // Penyangga 1D untuk mencegah error 2D memory bit-slicing pada parser lama
    wire [31:0] w1  = w_reg[1];
    wire [31:0] w14 = w_reg[14];

    // Gamma0(w1) = ROTR7(w1) ^ ROTR18(w1) ^ (w1 >> 3)
    wire [31:0] gam0_val = {w1[6:0], w1[31:7]} ^ {w1[17:0], w1[31:18]} ^ (w1 >> 3);

    // Gamma1(w14) = ROTR17(w14) ^ ROTR19(w14) ^ (w14 >> 10)
    wire [31:0] gam1_val = {w14[16:0], w14[31:17]} ^ {w14[18:0], w14[31:19]} ^ (w14 >> 10);

    // Nilai W saat ini dan W baru untuk pergeseran shift register
    wire [31:0] w_cur = w_reg[0];
    wire [31:0] w_new = w_reg[0] + gam0_val + w_reg[9] + gam1_val;

    // Kalkulasi Round T1 & T2
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
            for (i = 0; i < 16; i = i + 1) begin
                w_reg[i] <= 32'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        ready <= 1'b0;
                        state <= S_ROUNDS;
                        round_cnt <= 6'd0;
                        // Inisialisasi register kerja A..H
                        a <= H0_INIT;
                        b <= H1_INIT;
                        c <= H2_INIT;
                        d <= H3_INIT;
                        e <= H4_INIT;
                        f <= H5_INIT;
                        g <= H6_INIT;
                        h <= H7_INIT;
                        // Muat 16 kata pertama (512-bit) ke w_reg
                        w_reg[0]  <= block_512[511:480];
                        w_reg[1]  <= block_512[479:448];
                        w_reg[2]  <= block_512[447:416];
                        w_reg[3]  <= block_512[415:384];
                        w_reg[4]  <= block_512[383:352];
                        w_reg[5]  <= block_512[351:320];
                        w_reg[6]  <= block_512[319:288];
                        w_reg[7]  <= block_512[287:256];
                        w_reg[8]  <= block_512[255:224];
                        w_reg[9]  <= block_512[223:192];
                        w_reg[10] <= block_512[191:160];
                        w_reg[11] <= block_512[159:128];
                        w_reg[12] <= block_512[127:96];
                        w_reg[13] <= block_512[95:64];
                        w_reg[14] <= block_512[63:32];
                        w_reg[15] <= block_512[31:0];
                    end else begin
                        ready <= 1'b1;
                    end
                end

                S_ROUNDS: begin
                    // Perbarui variabel kompresi A..H
                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + t1;
                    d <= c;
                    c <= b;
                    b <= a;
                    a <= t1 + t2;

                    // Pergeseran jendela message schedule (Shift Register W)
                    for (i = 0; i < 15; i = i + 1) begin
                        w_reg[i] <= w_reg[i+1];
                    end
                    w_reg[15] <= w_new;

                    if (round_cnt == 6'd63) begin
                        state <= S_FINALIZE;
                    end else begin
                        round_cnt <= round_cnt + 6'd1;
                    end
                end

                S_FINALIZE: begin
                    // Penjumlahan akhir dengan nilai awal (Davies-Meyer construction)
                    digest <= {
                        (a + H0_INIT),
                        (b + H1_INIT),
                        (c + H2_INIT),
                        (d + H3_INIT),
                        (e + H4_INIT),
                        (f + H5_INIT),
                        (g + H6_INIT),
                        (h + H7_INIT)
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
