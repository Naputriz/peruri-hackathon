// ============================================================================
// Platform: Chip Merah Putih Sandbox (chip.peruri.co.id)
// Module: GarbleChip Synthesizable Design (100% Universal Verilog-1995/2001/2005)
// ============================================================================
`timescale 1ns / 1ps


// ============================================================================
// File: sha256_k_constants.v
// Module: sha256_k_constants
// Description: ROM 64 konstanta 32-bit (K0..K63) sesuai standar NIST FIPS 180-4
//              100% Universal Verilog (Verilog-1995, 2001, 2005, SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps

module sha256_k_constants (
    round_idx,
    k_out
);
    input  [5:0]  round_idx;
    output [31:0] k_out;
    reg    [31:0] k_out;

    always @(round_idx) begin
        case (round_idx)
            6'd0:  k_out = 32'h428a2f98;
            6'd1:  k_out = 32'h71374491;
            6'd2:  k_out = 32'hb5c0fbcf;
            6'd3:  k_out = 32'he9b5dba5;
            6'd4:  k_out = 32'h3956c25b;
            6'd5:  k_out = 32'h59f111f1;
            6'd6:  k_out = 32'h923f82a4;
            6'd7:  k_out = 32'hab1c5ed5;
            6'd8:  k_out = 32'hd807aa98;
            6'd9:  k_out = 32'h12835b01;
            6'd10: k_out = 32'h243185be;
            6'd11: k_out = 32'h550c7dc3;
            6'd12: k_out = 32'h72be5d74;
            6'd13: k_out = 32'h80deb1fe;
            6'd14: k_out = 32'h9bdc06a7;
            6'd15: k_out = 32'hc19bf174;
            6'd16: k_out = 32'he49b69c1;
            6'd17: k_out = 32'hefbe4786;
            6'd18: k_out = 32'h0fc19dc6;
            6'd19: k_out = 32'h240ca1cc;
            6'd20: k_out = 32'h2de92c6f;
            6'd21: k_out = 32'h4a7484aa;
            6'd22: k_out = 32'h5cb0a9dc;
            6'd23: k_out = 32'h76f988da;
            6'd24: k_out = 32'h983e5152;
            6'd25: k_out = 32'ha831c66d;
            6'd26: k_out = 32'hb00327c8;
            6'd27: k_out = 32'hbf597fc7;
            6'd28: k_out = 32'hc6e00bf3;
            6'd29: k_out = 32'hd5a79147;
            6'd30: k_out = 32'h06ca6351;
            6'd31: k_out = 32'h14292967;
            6'd32: k_out = 32'h27b70a85;
            6'd33: k_out = 32'h2e1b2138;
            6'd34: k_out = 32'h4d2c6dfc;
            6'd35: k_out = 32'h53380d13;
            6'd36: k_out = 32'h650a7354;
            6'd37: k_out = 32'h766a0abb;
            6'd38: k_out = 32'h81c2c92e;
            6'd39: k_out = 32'h92722c85;
            6'd40: k_out = 32'ha2bfe8a1;
            6'd41: k_out = 32'ha81a664b;
            6'd42: k_out = 32'hc24b8b70;
            6'd43: k_out = 32'hc76c51a3;
            6'd44: k_out = 32'hd192e819;
            6'd45: k_out = 32'hd6990624;
            6'd46: k_out = 32'hf40e3585;
            6'd47: k_out = 32'h106aa070;
            6'd48: k_out = 32'h19a4c116;
            6'd49: k_out = 32'h1e376c08;
            6'd50: k_out = 32'h2748774c;
            6'd51: k_out = 32'h34b0bcb5;
            6'd52: k_out = 32'h391c0cb3;
            6'd53: k_out = 32'h4ed8aa4a;
            6'd54: k_out = 32'h5b9cca4f;
            6'd55: k_out = 32'h682e6ff3;
            6'd56: k_out = 32'h748f82ee;
            6'd57: k_out = 32'h78a5636f;
            6'd58: k_out = 32'h84c87814;
            6'd59: k_out = 32'h8cc70208;
            6'd60: k_out = 32'h90befffa;
            6'd61: k_out = 32'ha4506ceb;
            6'd62: k_out = 32'hbef9a3f7;
            6'd63: k_out = 32'hc67178f2;
            default: k_out = 32'h00000000;
        endcase
    end

endmodule


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


// ============================================================================
// File: wire_label_ram.v
// Module: wire_label_ram
// Description: Scratchpad RAM 128-bit untuk menyimpan label kawat aktif
//              Dua port baca (wire_a, wire_b) dan satu port tulis (wire_out)
//              100% Universal Verilog (Verilog-1995, 2001, 2005, SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps

module wire_label_ram (
    clk,
    we,
    wr_addr,
    wr_data,
    rd_addr_a,
    rd_data_a,
    rd_addr_b,
    rd_data_b
);
    parameter ADDR_WIDTH = 8;   // 256 baris label kawat
    parameter DATA_WIDTH = 128; // 128-bit label kawat per entri

    input                  clk;
    input                  we;
    input  [ADDR_WIDTH-1:0] wr_addr;
    input  [DATA_WIDTH-1:0] wr_data;
    input  [ADDR_WIDTH-1:0] rd_addr_a;
    output [DATA_WIDTH-1:0] rd_data_a;
    input  [ADDR_WIDTH-1:0] rd_addr_b;
    output [DATA_WIDTH-1:0] rd_data_b;

    // Array memori internal scratchpad
    reg [DATA_WIDTH-1:0] mem [0:255];

    always @(posedge clk) begin
        if (we) begin
            mem[wr_addr] <= wr_data;
        end
    end

    // Asynchronous / combinational read untuk meminimalkan latency FSM
    assign rd_data_a = mem[rd_addr_a];
    assign rd_data_b = mem[rd_addr_b];

endmodule


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


// ============================================================================
// File: garble_gate_fsm.v
// Module: garble_gate_fsm
// Description: FSM Controller untuk Evaluasi Yao's Garbled Circuit
//              Mendukung Free-XOR (0-cycle) & Half-Gates AND (SHA-256 PRF)
//              100% Universal Verilog (Verilog-1995, 2001, 2005, SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps

module garble_gate_fsm (
    clk,
    rst_n,
    cmd_valid,
    cmd_ready,
    cmd_opcode,
    cmd_wire_out,
    cmd_wire_in1,
    cmd_wire_in2,
    cmd_gate_id,
    cmd_data_t0,
    cmd_data_t1,
    eval_busy,
    eval_done,
    match_result,
    cycle_counter,
    sha_start,
    sha_block,
    sha_ready,
    sha_done,
    sha_digest,
    ram_we,
    ram_wr_addr,
    ram_wr_data,
    ram_rd_addr_a,
    ram_rd_data_a,
    ram_rd_addr_b,
    ram_rd_data_b,
    xor_in_a,
    xor_in_b,
    xor_out
);
    input          clk;
    input          rst_n;

    // Antarmuka Perintah Gerbang
    input          cmd_valid;
    output         cmd_ready;
    reg            cmd_ready;
    input  [7:0]   cmd_opcode;      // 0x01: LOAD, 0x02: XOR, 0x03: AND, 0xFF: FINISH
    input  [7:0]   cmd_wire_out;
    input  [7:0]   cmd_wire_in1;
    input  [7:0]   cmd_wire_in2;
    input  [31:0]  cmd_gate_id;
    input  [127:0] cmd_data_t0;     // Label untuk LOAD / TG untuk AND / Exp label untuk FINISH
    input  [127:0] cmd_data_t1;     // TE untuk AND

    // Status & Hasil Evaluasi
    output         eval_busy;
    reg            eval_busy;
    output         eval_done;
    reg            eval_done;
    output         match_result;
    reg            match_result;
    output [31:0]  cycle_counter;
    reg    [31:0]  cycle_counter;

    // Antarmuka SHA-256 Core
    output         sha_start;
    reg            sha_start;
    output [511:0] sha_block;
    reg    [511:0] sha_block;
    input          sha_ready;
    input          sha_done;
    input  [255:0] sha_digest;

    // Antarmuka Wire Label RAM
    output         ram_we;
    reg            ram_we;
    output [7:0]   ram_wr_addr;
    reg    [7:0]   ram_wr_addr;
    output [127:0] ram_wr_data;
    reg    [127:0] ram_wr_data;
    output [7:0]   ram_rd_addr_a;
    reg    [7:0]   ram_rd_addr_a;
    input  [127:0] ram_rd_data_a;
    output [7:0]   ram_rd_addr_b;
    reg    [7:0]   ram_rd_addr_b;
    input  [127:0] ram_rd_data_b;

    // Antarmuka Free-XOR Unit
    output [127:0] xor_in_a;
    output [127:0] xor_in_b;
    input  [127:0] xor_out;

    // Opcodes
    parameter OP_LOAD   = 8'h01;
    parameter OP_XOR    = 8'h02;
    parameter OP_AND    = 8'h03;
    parameter OP_FINISH = 8'hFF;

    // FSM States
    parameter ST_IDLE         = 0;
    parameter ST_DISPATCH     = 1;
    parameter ST_LOAD_EXEC    = 2;
    parameter ST_XOR_EXEC     = 3;
    parameter ST_AND_HASH_A   = 4;
    parameter ST_AND_WAIT_A   = 5;
    parameter ST_AND_HASH_B   = 6;
    parameter ST_AND_WAIT_B   = 7;
    parameter ST_AND_FINALIZE = 8;
    parameter ST_DONE         = 9;

    reg [3:0] state;

    // Register internal penampung gerbang saat ini
    reg [7:0]   reg_out_id;
    reg [7:0]   reg_in1_id;
    reg [7:0]   reg_in2_id;
    reg [31:0]  reg_gate_id;
    reg [127:0] reg_t0;
    reg [127:0] reg_t1;

    // Register penyimpan label kawat A dan B yang dibaca
    reg [127:0] label_a_reg;
    reg [127:0] label_b_reg;
    reg [127:0] wg_reg;
    reg [127:0] we_reg;

    // Koneksi langsung Free-XOR
    assign xor_in_a = ram_rd_data_a;
    assign xor_in_b = ram_rd_data_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_IDLE;
            cmd_ready     <= 1'b1;
            eval_busy     <= 1'b0;
            eval_done     <= 1'b0;
            match_result  <= 1'b0;
            cycle_counter <= 32'd0;
            sha_start     <= 1'b0;
            sha_block     <= {16{32'h0}};
            ram_we        <= 1'b0;
            ram_wr_addr   <= 8'd0;
            ram_wr_data   <= 128'd0;
            ram_rd_addr_a <= 8'd0;
            ram_rd_addr_b <= 8'd0;
            reg_out_id    <= 8'd0;
            reg_in1_id    <= 8'd0;
            reg_in2_id    <= 8'd0;
            reg_gate_id   <= 32'd0;
            reg_t0        <= 128'd0;
            reg_t1        <= 128'd0;
            label_a_reg   <= 128'd0;
            label_b_reg   <= 128'd0;
            wg_reg        <= 128'd0;
            we_reg        <= 128'd0;
        end else begin
            // Hitung siklus clock saat sedang sibuk (benchmarking)
            if (eval_busy && !eval_done) begin
                cycle_counter <= cycle_counter + 32'd1;
            end

            case (state)
                ST_IDLE: begin
                    ram_we    <= 1'b0;
                    sha_start <= 1'b0;
                    eval_done <= 1'b0;

                    if (cmd_valid && cmd_ready) begin
                        eval_busy   <= 1'b1;
                        cmd_ready   <= 1'b0;
                        reg_out_id  <= cmd_wire_out;
                        reg_in1_id  <= cmd_wire_in1;
                        reg_in2_id  <= cmd_wire_in2;
                        reg_gate_id <= cmd_gate_id;
                        reg_t0      <= cmd_data_t0;
                        reg_t1      <= cmd_data_t1;

                        // Siapkan alamat baca RAM untuk input kawat
                        ram_rd_addr_a <= cmd_wire_in1;
                        ram_rd_addr_b <= cmd_wire_in2;

                        case (cmd_opcode)
                            OP_LOAD:   state <= ST_LOAD_EXEC;
                            OP_XOR:    state <= ST_XOR_EXEC;
                            OP_AND:    state <= ST_DISPATCH;
                            OP_FINISH: begin
                                ram_rd_addr_a <= cmd_wire_out;
                                state         <= ST_DONE;
                            end
                            default:   state <= ST_IDLE;
                        endcase
                    end else begin
                        cmd_ready <= 1'b1;
                    end
                end

                // 1. Eksekusi LOAD_WIRE
                ST_LOAD_EXEC: begin
                    ram_we      <= 1'b1;
                    ram_wr_addr <= reg_out_id;
                    ram_wr_data <= reg_t0;
                    cmd_ready   <= 1'b1;
                    eval_busy   <= 1'b0;
                    state       <= ST_IDLE;
                end

                // 2. Eksekusi EVAL_XOR (Free-XOR, 0 Siklus)
                ST_XOR_EXEC: begin
                    ram_we      <= 1'b1;
                    ram_wr_addr <= reg_out_id;
                    ram_wr_data <= xor_out;
                    cmd_ready   <= 1'b1;
                    eval_busy   <= 1'b0;
                    state       <= ST_IDLE;
                end

                // 3. Dispatch untuk Evaluasi Half-Gates AND
                ST_DISPATCH: begin
                    label_a_reg <= ram_rd_data_a;
                    label_b_reg <= ram_rd_data_b;
                    state       <= ST_AND_HASH_A;
                end

                // 4. Hash Generator Gate G (Input: Wire A)
                ST_AND_HASH_A: begin
                    if (sha_ready) begin
                        sha_block <= {
                            label_a_reg,
                            reg_gate_id,
                            8'h80,
                            280'h0,
                            64'd160
                        };
                        sha_start <= 1'b1;
                        state     <= ST_AND_WAIT_A;
                    end
                end

                ST_AND_WAIT_A: begin
                    sha_start <= 1'b0;
                    if (sha_done) begin
                        if (label_a_reg[0] == 1'b1) begin
                            wg_reg <= sha_digest[255:128] ^ reg_t0;
                        end else begin
                            wg_reg <= sha_digest[255:128];
                        end
                        state <= ST_AND_HASH_B;
                    end
                end

                // 5. Hash Evaluator Gate E (Input: Wire B)
                ST_AND_HASH_B: begin
                    if (sha_ready) begin
                        sha_block <= {
                            label_b_reg,
                            reg_gate_id,
                            8'h80,
                            280'h0,
                            64'd160
                        };
                        sha_start <= 1'b1;
                        state     <= ST_AND_WAIT_B;
                    end
                end

                ST_AND_WAIT_B: begin
                    sha_start <= 1'b0;
                    if (sha_done) begin
                        if (label_b_reg[0] == 1'b1) begin
                            we_reg <= sha_digest[255:128] ^ reg_t1 ^ label_a_reg;
                        end else begin
                            we_reg <= sha_digest[255:128];
                        end
                        state <= ST_AND_FINALIZE;
                    end
                end

                // 6. Finalisasi Half-Gates AND: W_out = W_G ^ W_E
                ST_AND_FINALIZE: begin
                    ram_we      <= 1'b1;
                    ram_wr_addr <= reg_out_id;
                    ram_wr_data <= wg_reg ^ we_reg;
                    cmd_ready   <= 1'b1;
                    eval_busy   <= 1'b0;
                    state       <= ST_IDLE;
                end

                // 7. Selesai Evaluasi Keseluruhan (FINISH)
                ST_DONE: begin
                    eval_done    <= 1'b1;
                    eval_busy    <= 1'b0;
                    cmd_ready    <= 1'b1;
                    match_result <= (ram_rd_data_a == reg_t0);
                    state        <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule


// ============================================================================
// File: garblechip_top.v
// Module: garblechip_top
// Description: Top-Level Synthesizable IP Core GarbleChip
//              Mengintegrasikan FSM Evaluator, SHA-256 Iterative Core,
//              Free-XOR Unit, dan Wire Label Scratchpad RAM.
//              100% Universal Verilog (Verilog-1995, 2001, 2005, SystemVerilog)
// ============================================================================

`timescale 1ns / 1ps

module garblechip_top (
    clk,
    rst_n,
    cmd_valid,
    cmd_ready,
    cmd_opcode,
    cmd_wire_out,
    cmd_wire_in1,
    cmd_wire_in2,
    cmd_gate_id,
    cmd_data_t0,
    cmd_data_t1,
    status_busy,
    status_done,
    status_match,
    total_cycles
);
    input          clk;
    input          rst_n;

    // Antarmuka Streaming Perintah
    input          cmd_valid;
    output         cmd_ready;
    wire           cmd_ready;
    input  [7:0]   cmd_opcode;      // 0x01: LOAD, 0x02: XOR, 0x03: AND, 0xFF: FINISH
    input  [7:0]   cmd_wire_out;
    input  [7:0]   cmd_wire_in1;
    input  [7:0]   cmd_wire_in2;
    input  [31:0]  cmd_gate_id;
    input  [127:0] cmd_data_t0;
    input  [127:0] cmd_data_t1;

    // Status & Indikator On-Board (LED DE10-Nano)
    output         status_busy;
    wire           status_busy;
    output         status_done;
    wire           status_done;
    output         status_match;
    wire           status_match;
    output [31:0]  total_cycles;
    wire   [31:0]  total_cycles;

    // Kawat Interkoneksi SHA-256
    wire         sha_start;
    wire [511:0] sha_block;
    wire         sha_ready;
    wire         sha_done;
    wire [255:0] sha_digest;

    // Kawat Interkoneksi RAM
    wire         ram_we;
    wire [7:0]   ram_wr_addr;
    wire [127:0] ram_wr_data;
    wire [7:0]   ram_rd_addr_a;
    wire [127:0] ram_rd_data_a;
    wire [7:0]   ram_rd_addr_b;
    wire [127:0] ram_rd_data_b;

    // Kawat Interkoneksi Free-XOR
    wire [127:0] xor_in_a;
    wire [127:0] xor_in_b;
    wire [127:0] xor_out;

    // 1. Instansiasi Scratchpad RAM Label Kawat
    wire_label_ram u_wire_ram (
        .clk       (clk),
        .we        (ram_we),
        .wr_addr   (ram_wr_addr),
        .wr_data   (ram_wr_data),
        .rd_addr_a (ram_rd_addr_a),
        .rd_data_a (ram_rd_data_a),
        .rd_addr_b (ram_rd_addr_b),
        .rd_data_b (ram_rd_data_b)
    );

    // 2. Instansiasi Unit Logika Free-XOR (0-cycle)
    free_xor_unit u_xor_unit (
        .label_a   (xor_in_a),
        .label_b   (xor_in_b),
        .label_out (xor_out)
    );

    // 3. Instansiasi SHA-256 Iterative Core PRF Engine (64 siklus)
    sha256_iterative_core u_sha256 (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (sha_start),
        .block_512 (sha_block),
        .ready     (sha_ready),
        .done      (sha_done),
        .digest    (sha_digest)
    );

    // 4. Instansiasi FSM Controller Evaluator Sirkuit
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


