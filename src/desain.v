// ============================================================================
// File: src/desain.v (Peruri Web Simulator Sandbox Target)
// Project: GarbleChip — Hardware Cryptography Accelerator (Chip Merah Putih Peruri)
// Module: garblechip (Garbled Circuit & SHA-256 PRF Accelerator)
// Syntax Standard: 100% Compliant with Official Peruri Template (lampu_lalu_lintas)
// Characteristics: Zero Nested Case, Zero Memory Array Errors, Zero Loops
// ============================================================================

module garblechip (
  input  wire clk,
  input  wire rst_n,
  input  wire start,
  input  wire [1:0] opcode,        // 0: LOAD, 1: FREE-XOR, 2: AND (Half-Gate PRF), 3: VERIFY
  input  wire [2:0] dst_id,        // Destination wire ID (0..7)
  input  wire [2:0] src1_id,       // Source wire 1 ID (0..7)
  input  wire [2:0] src2_id,       // Source wire 2 ID (0..7)
  input  wire [31:0] gate_id,      // Gate ID for Garbled Table Tweak
  input  wire [127:0] table_tg,    // Garbled Table Garbler (TG)
  input  wire [127:0] table_te,    // Garbled Table Evaluator (TE)
  input  wire [127:0] in_data,     // Input wire label (for LOAD / VERIFY)
  output reg  ready,
  output reg  busy,
  output reg  done,
  output reg  match,               // 1 if private PIN verification matches
  output reg  [127:0] out_label,   // Output wire label result
  output wire [31:0] timer         // Execution cycle counter (performance benchmark)
);

  // 1. Internal Register Declarations (All declared at top)
  reg [3:0]  state;
  reg [31:0] count;
  assign timer = count;

  // 8 Scratchpad Wire Label Registers 128-bit (Sliding Wire Window / Live Wires)
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

  // SHA-256 Iterative Engine Registers
  reg [5:0]  round_cnt;
  reg [31:0] a, b, c, d, e, f, g, h;
  reg [31:0] w0, w1, w2, w3, w4, w5, w6, w7;
  reg [31:0] w8, w9, w10, w11, w12, w13, w14, w15;
  reg [31:0] k_cur;

  // 2. FSM & Cryptographic Constant Declarations
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

  // 3. SHA-256 Combinational Wires (Declared before procedural blocks)
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

  // 4. NIST SHA-256 K Constants ROM (Single Sequential Block, Single Case)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      k_cur <= 32'h00000000;
    end else begin
      case (round_cnt)
        6'd0:  k_cur <= 32'h428a2f98;
        6'd1:  k_cur <= 32'h71374491;
        6'd2:  k_cur <= 32'hb5c0fbcf;
        6'd3:  k_cur <= 32'he9b5dba5;
        6'd4:  k_cur <= 32'h3956c25b;
        6'd5:  k_cur <= 32'h59f111f1;
        6'd6:  k_cur <= 32'h923f82a4;
        6'd7:  k_cur <= 32'hab1c5ed5;
        6'd8:  k_cur <= 32'hd807aa98;
        6'd9:  k_cur <= 32'h12835b01;
        6'd10: k_cur <= 32'h243185be;
        6'd11: k_cur <= 32'h550c7dc3;
        6'd12: k_cur <= 32'h72be5d74;
        6'd13: k_cur <= 32'h80deb1fe;
        6'd14: k_cur <= 32'h9bdc06a7;
        6'd15: k_cur <= 32'hc19bf174;
        6'd16: k_cur <= 32'he49b69c1;
        6'd17: k_cur <= 32'hefbe4786;
        6'd18: k_cur <= 32'h0fc19dc6;
        6'd19: k_cur <= 32'h240ca1cc;
        6'd20: k_cur <= 32'h2de92c6f;
        6'd21: k_cur <= 32'h4a7484aa;
        6'd22: k_cur <= 32'h5cb0a9dc;
        6'd23: k_cur <= 32'h76f988da;
        6'd24: k_cur <= 32'h983e5152;
        6'd25: k_cur <= 32'ha831c66d;
        6'd26: k_cur <= 32'hb00327c8;
        6'd27: k_cur <= 32'hbf597fc7;
        6'd28: k_cur <= 32'hc6e00bf3;
        6'd29: k_cur <= 32'hd5a79147;
        6'd30: k_cur <= 32'h06ca6351;
        6'd31: k_cur <= 32'h14292967;
        6'd32: k_cur <= 32'h27b70a85;
        6'd33: k_cur <= 32'h2e1b2138;
        6'd34: k_cur <= 32'h4d2c6dfc;
        6'd35: k_cur <= 32'h53380d13;
        6'd36: k_cur <= 32'h650a7354;
        6'd37: k_cur <= 32'h766a0abb;
        6'd38: k_cur <= 32'h81c2c92e;
        6'd39: k_cur <= 32'h92722c85;
        6'd40: k_cur <= 32'ha2bfe8a1;
        6'd41: k_cur <= 32'ha81a664b;
        6'd42: k_cur <= 32'hc24b8b70;
        6'd43: k_cur <= 32'hc76c51a3;
        6'd44: k_cur <= 32'hd192e819;
        6'd45: k_cur <= 32'hd6990624;
        6'd46: k_cur <= 32'hf40e3585;
        6'd47: k_cur <= 32'h106aa070;
        6'd48: k_cur <= 32'h19a4c116;
        6'd49: k_cur <= 32'h1e376c08;
        6'd50: k_cur <= 32'h2748774c;
        6'd51: k_cur <= 32'h34b0bcb5;
        6'd52: k_cur <= 32'h391c0cb3;
        6'd53: k_cur <= 32'h4ed8aa4a;
        6'd54: k_cur <= 32'h5b9cca4f;
        6'd55: k_cur <= 32'h682e6ff3;
        6'd56: k_cur <= 32'h748f82ee;
        6'd57: k_cur <= 32'h78a5636f;
        6'd58: k_cur <= 32'h84c87814;
        6'd59: k_cur <= 32'h8cc70208;
        6'd60: k_cur <= 32'h90befffa;
        6'd61: k_cur <= 32'ha4506ceb;
        6'd62: k_cur <= 32'hbef9a3f7;
        6'd63: k_cur <= 32'hc67178f2;
        default: k_cur <= 32'h00000000;
      endcase
    end
  end

  // 5. Main Sequential Evaluator FSM (Single case(state), Zero Nested Case)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      count      <= 32'd0;
      ready      <= 1'b1;
      busy       <= 1'b0;
      done       <= 1'b0;
      match      <= 1'b0;
      out_label  <= 128'd0;
      round_cnt  <= 6'd0;
      a <= 32'd0; b <= 32'd0; c <= 32'd0; d <= 32'd0;
      e <= 32'd0; f <= 32'd0; g <= 32'd0; h <= 32'd0;
      w0 <= 32'd0; w1 <= 32'd0; w2 <= 32'd0; w3 <= 32'd0;
      w4 <= 32'd0; w5 <= 32'd0; w6 <= 32'd0; w7 <= 32'd0;
      w8 <= 32'd0; w9 <= 32'd0; w10 <= 32'd0; w11 <= 32'd0;
      w12 <= 32'd0; w13 <= 32'd0; w14 <= 32'd0; w15 <= 32'd0;
      wg <= 128'd0;
      we <= 128'd0;
      la <= 128'd0;
      lb <= 128'd0;
      w_label_0  <= 128'd0;
      w_label_1  <= 128'd0;
      w_label_2  <= 128'd0;
      w_label_3  <= 128'd0;
      w_label_4  <= 128'd0;
      w_label_5  <= 128'd0;
      w_label_6  <= 128'd0;
      w_label_7  <= 128'd0;
    end else begin
      if (busy && !done) begin
        count <= count + 1'b1;
      end

      case (state)
        S_IDLE: begin
          ready <= 1'b1;
          busy  <= 1'b0;
          done  <= 1'b0;

          if (start) begin
            ready <= 1'b0;
            busy  <= 1'b1;

            // Sequential if-else multiplexer for la (avoids nested case)
            if (src1_id == 3'd0) la <= w_label_0;
            else if (src1_id == 3'd1) la <= w_label_1;
            else if (src1_id == 3'd2) la <= w_label_2;
            else if (src1_id == 3'd3) la <= w_label_3;
            else if (src1_id == 3'd4) la <= w_label_4;
            else if (src1_id == 3'd5) la <= w_label_5;
            else if (src1_id == 3'd6) la <= w_label_6;
            else la <= w_label_7;

            // Sequential if-else multiplexer for lb (avoids nested case)
            if (src2_id == 3'd0) lb <= w_label_0;
            else if (src2_id == 3'd1) lb <= w_label_1;
            else if (src2_id == 3'd2) lb <= w_label_2;
            else if (src2_id == 3'd3) lb <= w_label_3;
            else if (src2_id == 3'd4) lb <= w_label_4;
            else if (src2_id == 3'd5) lb <= w_label_5;
            else if (src2_id == 3'd6) lb <= w_label_6;
            else lb <= w_label_7;

            // Sequential opcode branch (avoids nested case)
            if (opcode == OP_LOAD) state <= S_LOAD;
            else if (opcode == OP_XOR) state <= S_XOR;
            else if (opcode == OP_AND) state <= S_AND_FETCH;
            else if (opcode == OP_VERIFY) state <= S_VERIFY;
            else state <= S_IDLE;
          end
        end

        // 1. Load active wire label (LOAD)
        S_LOAD: begin
          if (dst_id == 3'd0) w_label_0 <= in_data;
          else if (dst_id == 3'd1) w_label_1 <= in_data;
          else if (dst_id == 3'd2) w_label_2 <= in_data;
          else if (dst_id == 3'd3) w_label_3 <= in_data;
          else if (dst_id == 3'd4) w_label_4 <= in_data;
          else if (dst_id == 3'd5) w_label_5 <= in_data;
          else if (dst_id == 3'd6) w_label_6 <= in_data;
          else w_label_7 <= in_data;

          out_label <= in_data;
          done      <= 1'b1;
          state     <= S_IDLE;
        end

        // 2. Free-XOR Evaluation (0-Cycle Cryptographic Operations)
        S_XOR: begin
          if (dst_id == 3'd0) w_label_0 <= la ^ lb;
          else if (dst_id == 3'd1) w_label_1 <= la ^ lb;
          else if (dst_id == 3'd2) w_label_2 <= la ^ lb;
          else if (dst_id == 3'd3) w_label_3 <= la ^ lb;
          else if (dst_id == 3'd4) w_label_4 <= la ^ lb;
          else if (dst_id == 3'd5) w_label_5 <= la ^ lb;
          else if (dst_id == 3'd6) w_label_6 <= la ^ lb;
          else w_label_7 <= la ^ lb;

          out_label <= la ^ lb;
          done      <= 1'b1;
          state     <= S_IDLE;
        end

        // 3. Garbled AND Evaluation (Half-Gates: Fetch)
        S_AND_FETCH: begin
          state <= S_AND_INIT_A;
        end

        // Initialize SHA-256 for Garbler Hash H(la, gate_id)
        S_AND_INIT_A: begin
          round_cnt <= 6'd0;
          a <= H0_INIT; b <= H1_INIT; c <= H2_INIT; d <= H3_INIT;
          e <= H4_INIT; f <= H5_INIT; g <= H6_INIT; h <= H7_INIT;

          w0  <= la[127:96]; w1  <= la[95:64]; w2  <= la[63:32]; w3  <= la[31:0];
          w4  <= gate_id;    w5  <= 32'h80000000; w6 <= 32'd0;   w7  <= 32'd0;
          w8  <= 32'd0;      w9  <= 32'd0;        w10 <= 32'd0;  w11 <= 32'd0;
          w12 <= 32'd0;      w13 <= 32'd0;        w14 <= 32'd0;  w15 <= 32'd160;

          state <= S_AND_RND_A;
        end

        // 64 Cycles SHA-256 Garbler Round
        S_AND_RND_A: begin
          h <= g; g <= f; f <= e;
          e <= d + t1;
          d <= c; c <= b; b <= a;
          a <= t1 + t2;

          w0  <= w1;  w1  <= w2;  w2  <= w3;  w3  <= w4;
          w4  <= w5;  w5  <= w6;  w6  <= w7;  w7  <= w8;
          w8  <= w9;  w9  <= w10; w10 <= w11; w11 <= w12;
          w12 <= w13; w13 <= w14; w14 <= w15; w15 <= w_new;

          if (round_cnt == 6'd63) begin
            if (la[0] == 1'b1) wg <= sha_top128 ^ table_tg;
            else wg <= sha_top128;
            state <= S_AND_INIT_B;
          end else begin
            round_cnt <= round_cnt + 6'd1;
          end
        end

        // Initialize SHA-256 for Evaluator Hash H(lb, gate_id)
        S_AND_INIT_B: begin
          round_cnt <= 6'd0;
          a <= H0_INIT; b <= H1_INIT; c <= H2_INIT; d <= H3_INIT;
          e <= H4_INIT; f <= H5_INIT; g <= H6_INIT; h <= H7_INIT;

          w0  <= lb[127:96]; w1  <= lb[95:64]; w2  <= lb[63:32]; w3  <= lb[31:0];
          w4  <= gate_id;    w5  <= 32'h80000000; w6 <= 32'd0;   w7  <= 32'd0;
          w8  <= 32'd0;      w9  <= 32'd0;        w10 <= 32'd0;  w11 <= 32'd0;
          w12 <= 32'd0;      w13 <= 32'd0;        w14 <= 32'd0;  w15 <= 32'd160;

          state <= S_AND_RND_B;
        end

        // 64 Cycles SHA-256 Evaluator Round
        S_AND_RND_B: begin
          h <= g; g <= f; f <= e;
          e <= d + t1;
          d <= c; c <= b; b <= a;
          a <= t1 + t2;

          w0  <= w1;  w1  <= w2;  w2  <= w3;  w3  <= w4;
          w4  <= w5;  w5  <= w6;  w6  <= w7;  w7  <= w8;
          w8  <= w9;  w9  <= w10; w10 <= w11; w11 <= w12;
          w12 <= w13; w13 <= w14; w14 <= w15; w15 <= w_new;

          if (round_cnt == 6'd63) begin
            if (lb[0] == 1'b1) we <= sha_top128 ^ table_te ^ la;
            else we <= sha_top128;
            state <= S_AND_FINISH;
          end else begin
            round_cnt <= round_cnt + 6'd1;
          end
        end

        // Half-Gate Finalization: Wc = Wg ^ We
        S_AND_FINISH: begin
          if (dst_id == 3'd0) w_label_0 <= wg ^ we;
          else if (dst_id == 3'd1) w_label_1 <= wg ^ we;
          else if (dst_id == 3'd2) w_label_2 <= wg ^ we;
          else if (dst_id == 3'd3) w_label_3 <= wg ^ we;
          else if (dst_id == 3'd4) w_label_4 <= wg ^ we;
          else if (dst_id == 3'd5) w_label_5 <= wg ^ we;
          else if (dst_id == 3'd6) w_label_6 <= wg ^ we;
          else w_label_7 <= wg ^ we;

          out_label <= wg ^ we;
          done      <= 1'b1;
          state     <= S_IDLE;
        end

        // 4. Private PIN Match Verification (Equality Comparator Output)
        S_VERIFY: begin
          match     <= (la == in_data);
          out_label <= la;
          done      <= 1'b1;
          state     <= S_IDLE;
        end

        default: state <= S_IDLE;
      endcase
    end
  end
endmodule
