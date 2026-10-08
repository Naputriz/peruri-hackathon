// ============================================================================
// File: src/desain.v (Peruri Web Simulator Sandbox Target)
// Proyek: GarbleChip — Hardware Cryptography Accelerator (Chip Merah Putih Peruri)
// Modul: garblechip (Akselerator Garbled Circuit & SHA-256 PRF)
// Format Sintaks: 100% Mengikuti Standar Resmi Peruri (Template lampu_lalu_lintas)
// Karakteristik: Zero Nested Case, Zero Memory Array Error, Zero Loop For
// ============================================================================

module garblechip (
  input  wire clk,
  input  wire rst_n,
  input  wire start,
  input  wire [1:0] opcode,        // 0: LOAD, 1: FREE-XOR, 2: AND (Half-Gate PRF), 3: VERIFY
  input  wire [2:0] dst_id,        // Kawat tujuan (0..7)
  input  wire [2:0] src1_id,       // Kawat sumber 1 (0..7)
  input  wire [2:0] src2_id,       // Kawat sumber 2 (0..7)
  input  wire [31:0] gate_id,      // ID Gerbang untuk Garbled Table Tweak
  input  wire [127:0] table_tg,    // Garbled Table Garbler (TG)
  input  wire [127:0] table_te,    // Garbled Table Evaluator (TE)
  input  wire [127:0] in_data,     // Label kawat masukan (untuk LOAD / VERIFY)
  output reg  ready,
  output reg  busy,
  output reg  done,
  output reg  match,               // 1 jika verifikasi PIN cocok (Private Match)
  output reg  [127:0] out_label,   // Label kawat keluaran hasil evaluasi
  output wire [31:0] timer         // Indikator siklus eksekusi (benchmark akselerasi)
);

  // 1. Deklarasi Register Internal (Semua di paling atas)
  reg [3:0]  state;
  reg [31:0] count;
  assign timer = count;

  // 8 Register Scratchpad Kawat 128-bit (Sliding Wire Window / Live Wires)
  reg [127:0] w_label_0;
  reg [127:0] w_label_1;
  reg [127:0] w_label_2;
  reg [127:0] w_label_3;
  reg [127:0] w_label_4;
  reg [127:0] w_label_5;
  reg [127:0] w_label_6;
  reg [127:0] w_label_7;

  reg [127:0] la;
  reg [127:0] lb;
  reg [127:0] wg;
  reg [127:0] we;

  // Register SHA-256 Iterative Engine
  reg [5:0]  round_cnt;
  reg [31:0] a, b, c, d, e, f, g, h;
  reg [31:0] w0, w1, w2, w3, w4, w5, w6, w7;
  reg [31:0] w8, w9, w10, w11, w12, w13, w14, w15;
  reg [31:0] k_cur;

  // 2. Deklarasi Konstanta FSM & Kriptografi
  localparam S_IDLE       = 4'd0,
             S_LOAD       = 4'd1,
             S_XOR        = 4'd2,
             S_AND_FETCH  = 4'd3,
             S_AND_INIT_A = 4'd4,
             S_AND_RND_A  = 4'd5,
             S_AND_INIT_B = 4'd6,
             S_AND_RND_B  = 4'd7,
             S_AND_FINISH = 4'd8,
             S_VERIFY     = 4'd9;

  localparam OP_LOAD   = 2'd0,
             OP_XOR    = 2'd1,
             OP_AND    = 2'd2,
             OP_VERIFY = 2'd3;

  localparam H0_INIT = 32'h6a09e667,
             H1_INIT = 32'hbb67ae85,
             H2_INIT = 32'h3c6ef372,
             H3_INIT = 32'ha54ff53a,
             H4_INIT = 32'h510e527f,
             H5_INIT = 32'h9b05688c,
             H6_INIT = 32'h1f83d9ab,
             H7_INIT = 32'h5be0cd19;

  // 3. Wires Kombinasional SHA-256 (Dideklarasikan sebelum blok procedural)
  wire [31:0] ch_val   = (e & f) ^ (~e & g);
  wire [31:0] maj_val  = (a & b) ^ (a & c) ^ (b & c);
  wire [31:0] s0_val   = {a[1:0], a[31:2]} ^ {a[12:0], a[31:13]} ^ {a[21:0], a[31:22]};
  wire [31:0] s1_val   = {e[5:0], e[31:6]} ^ {e[10:0], e[31:11]} ^ {e[24:0], e[31:25]};
  wire [31:0] gam0_val = {w1[6:0], w1[31:7]}   ^ {w1[17:0], w1[31:18]}   ^ (w1 >> 3);
  wire [31:0] gam1_val = {w14[16:0], w14[31:17]} ^ {w14[18:0], w14[31:19]} ^ (w14 >> 10);
  wire [31:0] w_new    = w0 + gam0_val + w9 + gam1_val;
  wire [31:0] t1       = h + s1_val + ch_val + k_cur + w0;
  wire [31:0] t2       = s0_val + maj_val;
  wire [127:0] sha_top128 = {(a + H0_INIT), (b + H1_INIT), (c + H2_INIT), (d + H3_INIT)};

  // 4. ROM Konstanta K NIST SHA-256 (Blok Sekuensial Mandiri, Case Tunggal)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      k_cur &lt;= 32'h00000000;
    end else begin
      case (round_cnt)
        6'd0:  k_cur &lt;= 32'h428a2f98;
        6'd1:  k_cur &lt;= 32'h71374491;
        6'd2:  k_cur &lt;= 32'hb5c0fbcf;
        6'd3:  k_cur &lt;= 32'he9b5dba5;
        6'd4:  k_cur &lt;= 32'h3956c25b;
        6'd5:  k_cur &lt;= 32'h59f111f1;
        6'd6:  k_cur &lt;= 32'h923f82a4;
        6'd7:  k_cur &lt;= 32'hab1c5ed5;
        6'd8:  k_cur &lt;= 32'hd807aa98;
        6'd9:  k_cur &lt;= 32'h12835b01;
        6'd10: k_cur &lt;= 32'h243185be;
        6'd11: k_cur &lt;= 32'h550c7dc3;
        6'd12: k_cur &lt;= 32'h72be5d74;
        6'd13: k_cur &lt;= 32'h80deb1fe;
        6'd14: k_cur &lt;= 32'h9bdc06a7;
        6'd15: k_cur &lt;= 32'hc19bf174;
        6'd16: k_cur &lt;= 32'he49b69c1;
        6'd17: k_cur &lt;= 32'hefbe4786;
        6'd18: k_cur &lt;= 32'h0fc19dc6;
        6'd19: k_cur &lt;= 32'h240ca1cc;
        6'd20: k_cur &lt;= 32'h2de92c6f;
        6'd21: k_cur &lt;= 32'h4a7484aa;
        6'd22: k_cur &lt;= 32'h5cb0a9dc;
        6'd23: k_cur &lt;= 32'h76f988da;
        6'd24: k_cur &lt;= 32'h983e5152;
        6'd25: k_cur &lt;= 32'ha831c66d;
        6'd26: k_cur &lt;= 32'hb00327c8;
        6'd27: k_cur &lt;= 32'hbf597fc7;
        6'd28: k_cur &lt;= 32'hc6e00bf3;
        6'd29: k_cur &lt;= 32'hd5a79147;
        6'd30: k_cur &lt;= 32'h06ca6351;
        6'd31: k_cur &lt;= 32'h14292967;
        6'd32: k_cur &lt;= 32'h27b70a85;
        6'd33: k_cur &lt;= 32'h2e1b2138;
        6'd34: k_cur &lt;= 32'h4d2c6dfc;
        6'd35: k_cur &lt;= 32'h53380d13;
        6'd36: k_cur &lt;= 32'h650a7354;
        6'd37: k_cur &lt;= 32'h766a0abb;
        6'd38: k_cur &lt;= 32'h81c2c92e;
        6'd39: k_cur &lt;= 32'h92722c85;
        6'd40: k_cur &lt;= 32'ha2bfe8a1;
        6'd41: k_cur &lt;= 32'ha81a664b;
        6'd42: k_cur &lt;= 32'hc24b8b70;
        6'd43: k_cur &lt;= 32'hc76c51a3;
        6'd44: k_cur &lt;= 32'hd192e819;
        6'd45: k_cur &lt;= 32'hd6990624;
        6'd46: k_cur &lt;= 32'hf40e3585;
        6'd47: k_cur &lt;= 32'h106aa070;
        6'd48: k_cur &lt;= 32'h19a4c116;
        6'd49: k_cur &lt;= 32'h1e376c08;
        6'd50: k_cur &lt;= 32'h2748774c;
        6'd51: k_cur &lt;= 32'h34b0bcb5;
        6'd52: k_cur &lt;= 32'h391c0cb3;
        6'd53: k_cur &lt;= 32'h4ed8aa4a;
        6'd54: k_cur &lt;= 32'h5b9cca4f;
        6'd55: k_cur &lt;= 32'h682e6ff3;
        6'd56: k_cur &lt;= 32'h748f82ee;
        6'd57: k_cur &lt;= 32'h78a5636f;
        6'd58: k_cur &lt;= 32'h84c87814;
        6'd59: k_cur &lt;= 32'h8cc70208;
        6'd60: k_cur &lt;= 32'h90befffa;
        6'd61: k_cur &lt;= 32'ha4506ceb;
        6'd62: k_cur &lt;= 32'hbef9a3f7;
        6'd63: k_cur &lt;= 32'hc67178f2;
        default: k_cur &lt;= 32'h00000000;
      endcase
    end
  end

  // 5. FSM Sekuensial Utama Evaluator (Case Tunggal case(state), Zero Nested Case)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      &lt;= S_IDLE;
      count      &lt;= 32'd0;
      ready      &lt;= 1'b1;
      busy       &lt;= 1'b0;
      done       &lt;= 1'b0;
      match      &lt;= 1'b0;
      out_label  &lt;= 128'd0;
      round_cnt  &lt;= 6'd0;
      a &lt;= 32'd0; b &lt;= 32'd0; c &lt;= 32'd0; d &lt;= 32'd0;
      e &lt;= 32'd0; f &lt;= 32'd0; g &lt;= 32'd0; h &lt;= 32'd0;
      w0 &lt;= 32'd0; w1 &lt;= 32'd0; w2 &lt;= 32'd0; w3 &lt;= 32'd0;
      w4 &lt;= 32'd0; w5 &lt;= 32'd0; w6 &lt;= 32'd0; w7 &lt;= 32'd0;
      w8 &lt;= 32'd0; w9 &lt;= 32'd0; w10 &lt;= 32'd0; w11 &lt;= 32'd0;
      w12 &lt;= 32'd0; w13 &lt;= 32'd0; w14 &lt;= 32'd0; w15 &lt;= 32'd0;
      wg &lt;= 128'd0;
      we &lt;= 128'd0;
      la &lt;= 128'd0;
      lb &lt;= 128'd0;
      w_label_0  &lt;= 128'd0;
      w_label_1  &lt;= 128'd0;
      w_label_2  &lt;= 128'd0;
      w_label_3  &lt;= 128'd0;
      w_label_4  &lt;= 128'd0;
      w_label_5  &lt;= 128'd0;
      w_label_6  &lt;= 128'd0;
      w_label_7  &lt;= 128'd0;
    end else begin
      if (busy && !done) begin
        count &lt;= count + 1'b1;
      end

      case (state)
        S_IDLE: begin
          ready &lt;= 1'b1;
          busy  &lt;= 1'b0;
          done  &lt;= 1'b0;

          if (start) begin
            ready &lt;= 1'b0;
            busy  &lt;= 1'b1;

            // Pemilihan la via if-else sekuensial (Bukan nested case)
            if (src1_id == 3'd0) la &lt;= w_label_0;
            else if (src1_id == 3'd1) la &lt;= w_label_1;
            else if (src1_id == 3'd2) la &lt;= w_label_2;
            else if (src1_id == 3'd3) la &lt;= w_label_3;
            else if (src1_id == 3'd4) la &lt;= w_label_4;
            else if (src1_id == 3'd5) la &lt;= w_label_5;
            else if (src1_id == 3'd6) la &lt;= w_label_6;
            else la &lt;= w_label_7;

            // Pemilihan lb via if-else sekuensial (Bukan nested case)
            if (src2_id == 3'd0) lb &lt;= w_label_0;
            else if (src2_id == 3'd1) lb &lt;= w_label_1;
            else if (src2_id == 3'd2) lb &lt;= w_label_2;
            else if (src2_id == 3'd3) lb &lt;= w_label_3;
            else if (src2_id == 3'd4) lb &lt;= w_label_4;
            else if (src2_id == 3'd5) lb &lt;= w_label_5;
            else if (src2_id == 3'd6) lb &lt;= w_label_6;
            else lb &lt;= w_label_7;

            // Transisi Opcode via if-else sekuensial (Bukan nested case)
            if (opcode == OP_LOAD) state &lt;= S_LOAD;
            else if (opcode == OP_XOR) state &lt;= S_XOR;
            else if (opcode == OP_AND) state &lt;= S_AND_FETCH;
            else if (opcode == OP_VERIFY) state &lt;= S_VERIFY;
            else state &lt;= S_IDLE;
          end
        end

        // 1. Muat Label Kawat Aktif (LOAD)
        S_LOAD: begin
          if (dst_id == 3'd0) w_label_0 &lt;= in_data;
          else if (dst_id == 3'd1) w_label_1 &lt;= in_data;
          else if (dst_id == 3'd2) w_label_2 &lt;= in_data;
          else if (dst_id == 3'd3) w_label_3 &lt;= in_data;
          else if (dst_id == 3'd4) w_label_4 &lt;= in_data;
          else if (dst_id == 3'd5) w_label_5 &lt;= in_data;
          else if (dst_id == 3'd6) w_label_6 &lt;= in_data;
          else w_label_7 &lt;= in_data;

          out_label &lt;= in_data;
          done      &lt;= 1'b1;
          state     &lt;= S_IDLE;
        end

        // 2. Evaluasi Free-XOR (1 Siklus Akselerasi Instan, 0 Operasi Kripto)
        S_XOR: begin
          if (dst_id == 3'd0) w_label_0 &lt;= la ^ lb;
          else if (dst_id == 3'd1) w_label_1 &lt;= la ^ lb;
          else if (dst_id == 3'd2) w_label_2 &lt;= la ^ lb;
          else if (dst_id == 3'd3) w_label_3 &lt;= la ^ lb;
          else if (dst_id == 3'd4) w_label_4 &lt;= la ^ lb;
          else if (dst_id == 3'd5) w_label_5 &lt;= la ^ lb;
          else if (dst_id == 3'd6) w_label_6 &lt;= la ^ lb;
          else w_label_7 &lt;= la ^ lb;

          out_label &lt;= la ^ lb;
          done      &lt;= 1'b1;
          state     &lt;= S_IDLE;
        end

        // 3. Evaluasi Garbled AND (Half-Gates: Fetch)
        S_AND_FETCH: begin
          state &lt;= S_AND_INIT_A;
        end

        // Inisialisasi SHA-256 untuk Garbler Hash H(la, gate_id)
        S_AND_INIT_A: begin
          round_cnt &lt;= 6'd0;
          a &lt;= H0_INIT; b &lt;= H1_INIT; c &lt;= H2_INIT; d &lt;= H3_INIT;
          e &lt;= H4_INIT; f &lt;= H5_INIT; g &lt;= H6_INIT; h &lt;= H7_INIT;

          w0  &lt;= la[127:96]; w1  &lt;= la[95:64]; w2  &lt;= la[63:32]; w3  &lt;= la[31:0];
          w4  &lt;= gate_id;    w5  &lt;= 32'h80000000; w6 &lt;= 32'd0;   w7  &lt;= 32'd0;
          w8  &lt;= 32'd0;      w9  &lt;= 32'd0;        w10 &lt;= 32'd0;  w11 &lt;= 32'd0;
          w12 &lt;= 32'd0;      w13 &lt;= 32'd0;        w14 &lt;= 32'd0;  w15 &lt;= 32'd160;

          state &lt;= S_AND_RND_A;
        end

        // 64 Siklus SHA-256 Round Garbler
        S_AND_RND_A: begin
          h &lt;= g; g &lt;= f; f &lt;= e;
          e &lt;= d + t1;
          d &lt;= c; c &lt;= b; b &lt;= a;
          a &lt;= t1 + t2;

          w0  &lt;= w1;  w1  &lt;= w2;  w2  &lt;= w3;  w3  &lt;= w4;
          w4  &lt;= w5;  w5  &lt;= w6;  w6  &lt;= w7;  w7  &lt;= w8;
          w8  &lt;= w9;  w9  &lt;= w10; w10 &lt;= w11; w11 &lt;= w12;
          w12 &lt;= w13; w13 &lt;= w14; w14 &lt;= w15; w15 &lt;= w_new;

          if (round_cnt == 6'd63) begin
            if (la[0] == 1'b1) wg &lt;= sha_top128 ^ table_tg;
            else wg &lt;= sha_top128;
            state &lt;= S_AND_INIT_B;
          end else begin
            round_cnt &lt;= round_cnt + 6'd1;
          end
        end

        // Inisialisasi SHA-256 untuk Evaluator Hash H(lb, gate_id)
        S_AND_INIT_B: begin
          round_cnt &lt;= 6'd0;
          a &lt;= H0_INIT; b &lt;= H1_INIT; c &lt;= H2_INIT; d &lt;= H3_INIT;
          e &lt;= H4_INIT; f &lt;= H5_INIT; g &lt;= H6_INIT; h &lt;= H7_INIT;

          w0  &lt;= lb[127:96]; w1  &lt;= lb[95:64]; w2  &lt;= lb[63:32]; w3  &lt;= lb[31:0];
          w4  &lt;= gate_id;    w5  &lt;= 32'h80000000; w6 &lt;= 32'd0;   w7  &lt;= 32'd0;
          w8  &lt;= 32'd0;      w9  &lt;= 32'd0;        w10 &lt;= 32'd0;  w11 &lt;= 32'd0;
          w12 &lt;= 32'd0;      w13 &lt;= 32'd0;        w14 &lt;= 32'd0;  w15 &lt;= 32'd160;

          state &lt;= S_AND_RND_B;
        end

        // 64 Siklus SHA-256 Round Evaluator
        S_AND_RND_B: begin
          h &lt;= g; g &lt;= f; f &lt;= e;
          e &lt;= d + t1;
          d &lt;= c; c &lt;= b; b &lt;= a;
          a &lt;= t1 + t2;

          w0  &lt;= w1;  w1  &lt;= w2;  w2  &lt;= w3;  w3  &lt;= w4;
          w4  &lt;= w5;  w5  &lt;= w6;  w6  &lt;= w7;  w7  &lt;= w8;
          w8  &lt;= w9;  w9  &lt;= w10; w10 &lt;= w11; w11 &lt;= w12;
          w12 &lt;= w13; w13 &lt;= w14; w14 &lt;= w15; w15 &lt;= w_new;

          if (round_cnt == 6'd63) begin
            if (lb[0] == 1'b1) we &lt;= sha_top128 ^ table_te ^ la;
            else we &lt;= sha_top128;
            state &lt;= S_AND_FINISH;
          end else begin
            round_cnt &lt;= round_cnt + 6'd1;
          end
        end

        // Finalisasi Half-Gate: Wc = Wg ^ We
        S_AND_FINISH: begin
          if (dst_id == 3'd0) w_label_0 &lt;= wg ^ we;
          else if (dst_id == 3'd1) w_label_1 &lt;= wg ^ we;
          else if (dst_id == 3'd2) w_label_2 &lt;= wg ^ we;
          else if (dst_id == 3'd3) w_label_3 &lt;= wg ^ we;
          else if (dst_id == 3'd4) w_label_4 &lt;= wg ^ we;
          else if (dst_id == 3'd5) w_label_5 &lt;= wg ^ we;
          else if (dst_id == 3'd6) w_label_6 &lt;= wg ^ we;
          else w_label_7 &lt;= wg ^ we;

          out_label &lt;= wg ^ we;
          done      &lt;= 1'b1;
          state     &lt;= S_IDLE;
        end

        // 4. Verifikasi PIN Match (Equality Comparator Output)
        S_VERIFY: begin
          match     &lt;= (la == in_data);
          out_label &lt;= la;
          done      &lt;= 1'b1;
          state     &lt;= S_IDLE;
        end

        default: state &lt;= S_IDLE;
      endcase
    end
  end
endmodule