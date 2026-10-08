// ============================================================================
// File: src/sha256_core_iterative.v
// Module: sha256_core_iterative
// Description: Area-Efficient 64-Cycle Iterative SHA-256 512-bit Core
//              NIST FIPS 180-4 Standard for GarbleChip PRF Engine
//              Zero Loop (Unrolled Shift Pipeline), 100% Robust Verilog
// ============================================================================

`timescale 1ns / 1ps

module sha256_core_iterative (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [511:0] block_512,  // 16 32-bit words (M0..M15, MSB first)
    output reg          ready,
    output reg          done,
    output reg  [255:0] digest      // H0..H7 (256-bit)
);
    // Initial constants H0..H7
    localparam H0_INIT = 32'h6a09e667,
               H1_INIT = 32'hbb67ae85,
               H2_INIT = 32'h3c6ef372,
               H3_INIT = 32'ha54ff53a,
               H4_INIT = 32'h510e527f,
               H5_INIT = 32'h9b05688c,
               H6_INIT = 32'h1f83d9ab,
               H7_INIT = 32'h5be0cd19;

    // State machine
    localparam S_IDLE     = 2'd0,
               S_ROUNDS   = 2'd1,
               S_FINALIZE = 2'd2;

    reg [1:0]  state;
    reg [5:0]  round_cnt;

    // Working variables A..H
    reg [31:0] a, b, c, d, e, f, g, h;

    // Shift register array for Message Schedule W (16 x 32-bit)
    reg [31:0] w0, w1, w2, w3, w4, w5, w6, w7;
    reg [31:0] w8, w9, w10, w11, w12, w13, w14, w15;

    // ROM constants K
    wire [31:0] k_cur;
    sha256_k_constants u_k_constants (
        .round_idx (round_cnt),
        .k_out     (k_cur)
    );

    // NIST FIPS 180-4 Combinational Logic Functions
    wire [31:0] ch_val   = (e & f) ^ (~e & g);
    wire [31:0] maj_val  = (a & b) ^ (a & c) ^ (b & c);

    // NIST Sigma & Gamma via Bit-Slicing
    wire [31:0] s0_val   = {a[1:0], a[31:2]} ^ {a[12:0], a[31:13]} ^ {a[21:0], a[31:22]};
    wire [31:0] s1_val   = {e[5:0], e[31:6]} ^ {e[10:0], e[31:11]} ^ {e[24:0], e[31:25]};

    wire [31:0] gam0_val = {w1[6:0], w1[31:7]}   ^ {w1[17:0], w1[31:18]}   ^ (w1 >> 3);
    wire [31:0] gam1_val = {w14[16:0], w14[31:17]} ^ {w14[18:0], w14[31:19]} ^ (w14 >> 10);

    // Current W value and new W value for shift register update
    wire [31:0] w_cur = w0;
    wire [31:0] w_new = w0 + gam0_val + w9 + gam1_val;

    // Round computation T1 & T2
    wire [31:0] t1 = h + s1_val + ch_val + k_cur + w_cur;
    wire [31:0] t2 = s0_val + maj_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            ready     <= 1'b1;
            done      <= 1'b0;
            digest    <= 256'd0;
            round_cnt <= 6'd0;
            a <= 32'd0; b <= 32'd0; c <= 32'd0; d <= 32'd0;
            e <= 32'd0; f <= 32'd0; g <= 32'd0; h <= 32'd0;
            w0  <= 32'd0; w1  <= 32'd0; w2  <= 32'd0; w3  <= 32'd0;
            w4  <= 32'd0; w5  <= 32'd0; w6  <= 32'd0; w7  <= 32'd0;
            w8  <= 32'd0; w9  <= 32'd0; w10 <= 32'd0; w11 <= 32'd0;
            w12 <= 32'd0; w13 <= 32'd0; w14 <= 32'd0; w15 <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        ready     <= 1'b0;
                        state     <= S_ROUNDS;
                        round_cnt <= 6'd0;
                        // Initialize working registers A..H
                        a <= H0_INIT; b <= H1_INIT; c <= H2_INIT; d <= H3_INIT;
                        e <= H4_INIT; f <= H5_INIT; g <= H6_INIT; h <= H7_INIT;

                        // Load initial 16 words (512-bit block)
                        w0  <= block_512[511:480]; w1  <= block_512[479:448];
                        w2  <= block_512[447:416]; w3  <= block_512[415:384];
                        w4  <= block_512[383:352]; w5  <= block_512[351:320];
                        w6  <= block_512[319:288]; w7  <= block_512[287:256];
                        w8  <= block_512[255:224]; w9  <= block_512[223:192];
                        w10 <= block_512[191:160]; w11 <= block_512[159:128];
                        w12 <= block_512[127:96];  w13 <= block_512[95:64];
                        w14 <= block_512[63:32];   w15 <= block_512[31:0];
                    end else begin
                        ready <= 1'b1;
                    end
                end

                S_ROUNDS: begin
                    // Update compression variables A..H
                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + t1;
                    d <= c;
                    c <= b;
                    b <= a;
                    a <= t1 + t2;

                    // Shift message schedule window (100% Unrolled, No Loop)
                    w0  <= w1;  w1  <= w2;  w2  <= w3;  w3  <= w4;
                    w4  <= w5;  w5  <= w6;  w6  <= w7;  w7  <= w8;
                    w8  <= w9;  w9  <= w10; w10 <= w11; w11 <= w12;
                    w12 <= w13; w13 <= w14; w14 <= w15; w15 <= w_new;

                    if (round_cnt == 6'd63) begin
                        state <= S_FINALIZE;
                    end else begin
                        round_cnt <= round_cnt + 6'd1;
                    end
                end

                S_FINALIZE: begin
                    // Final addition with initial hash values (Davies-Meyer construction)
                    digest <= {
                        (a + H0_INIT), (b + H1_INIT), (c + H2_INIT), (d + H3_INIT),
                        (e + H4_INIT), (f + H5_INIT), (g + H6_INIT), (h + H7_INIT)
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
