// ============================================================================
// Platform: Chip Merah Putih Sandbox (chip.peruri.co.id)
// File: garblechip_sandbox_package.v
// Deskripsi: Paket lengkap mandiri (Self-Contained) GarbleChip IP Core
//            Siap di-Sintesis (RTL Viewer) dan di-Simulasi (Gelombang / Log)
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
// 2. Core SHA-256 Iteratif 64-Siklus
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

    // NIST Sigma & Gamma via Bit-Slicing Murni (Zero Gate)
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
                    h <= g; g <= f; f <= e;
                    e <= d + t1;
                    d <= c; c <= b; b <= a;
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
// 3. Free-XOR Unit (0-cycle kombinasional)
// ============================================================================
module free_xor_unit (
    input  wire [127:0] label_a,
    input  wire [127:0] label_b,
    output wire [127:0] label_out
);
    assign label_out = label_a ^ label_b;
endmodule

// ============================================================================
// 4. Scratchpad RAM Label Kawat (Dual-read, single-write)
// ============================================================================
module wire_label_ram (
    input  wire         clk,
    input  wire         we,
    input  wire [7:0]   wr_addr,
    input  wire [127:0] wr_data,
    input  wire [7:0]   rd_addr_a,
    output wire [127:0] rd_data_a,
    input  wire [7:0]   rd_addr_b,
    output wire [127:0] rd_data_b
);
    reg [127:0] mem [0:255];
    always @(posedge clk) begin
        if (we) mem[wr_addr] <= wr_data;
    end
    assign rd_data_a = mem[rd_addr_a];
    assign rd_data_b = mem[rd_addr_b];
endmodule

// ============================================================================
// 5. GarbleChip Top IP Core
// ============================================================================
module garblechip_top (
    input  wire         clk,
    input  wire         rst_n,

    input  wire         cmd_valid,
    output reg          cmd_ready,
    input  wire [7:0]   cmd_opcode,      // 0x01: LOAD, 0x02: XOR, 0x03: AND, 0xFF: FINISH
    input  wire [7:0]   cmd_wire_out,
    input  wire [7:0]   cmd_wire_in1,
    input  wire [7:0]   cmd_wire_in2,
    input  wire [31:0]  cmd_gate_id,
    input  wire [127:0] cmd_data_t0,
    input  wire [127:0] cmd_data_t1,

    output reg          status_busy,
    output reg          status_done,
    output reg          status_match,
    output reg  [31:0]  total_cycles
);
    // Kawat internal
    wire         sha_ready, sha_done;
    reg          sha_start;
    reg  [511:0] sha_block;
    wire [255:0] sha_digest;

    reg          ram_we;
    reg  [7:0]   ram_wr_addr;
    reg  [127:0] ram_wr_data;
    reg  [7:0]   ram_rd_addr_a;
    reg  [7:0]   ram_rd_addr_b;
    wire [127:0] ram_rd_data_a;
    wire [127:0] ram_rd_data_b;

    wire [127:0] xor_out;
    free_xor_unit u_xor (.label_a(ram_rd_data_a), .label_b(ram_rd_data_b), .label_out(xor_out));

    wire_label_ram u_ram (
        .clk(clk), .we(ram_we), .wr_addr(ram_wr_addr), .wr_data(ram_wr_data),
        .rd_addr_a(ram_rd_addr_a), .rd_data_a(ram_rd_data_a),
        .rd_addr_b(ram_rd_addr_b), .rd_data_b(ram_rd_data_b)
    );

    sha256_iterative_core u_sha (
        .clk(clk), .rst_n(rst_n), .start(sha_start), .block_512(sha_block),
        .ready(sha_ready), .done(sha_done), .digest(sha_digest)
    );

    parameter [3:0] ST_IDLE       = 4'd0;
    parameter [3:0] ST_LOAD_EXEC  = 4'd1;
    parameter [3:0] ST_XOR_EXEC   = 4'd2;
    parameter [3:0] ST_AND_FETCH  = 4'd3;
    parameter [3:0] ST_AND_HASH_A = 4'd4;
    parameter [3:0] ST_AND_WAIT_A = 4'd5;
    parameter [3:0] ST_AND_HASH_B = 4'd6;
    parameter [3:0] ST_AND_WAIT_B = 4'd7;
    parameter [3:0] ST_AND_FIN    = 4'd8;
    parameter [3:0] ST_DONE       = 4'd9;

    reg [3:0] state;
    reg [7:0] reg_out_id, reg_in1_id, reg_in2_id;
    reg [31:0] reg_gate_id;
    reg [127:0] reg_t0, reg_t1;
    reg [127:0] la_reg, lb_reg, wg_reg, we_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            cmd_ready    <= 1'b1;
            status_busy  <= 1'b0;
            status_done  <= 1'b0;
            status_match <= 1'b0;
            total_cycles <= 32'd0;
            sha_start    <= 1'b0;
            ram_we       <= 1'b0;
            reg_out_id   <= 8'd0;
            reg_in1_id   <= 8'd0;
            reg_in2_id   <= 8'd0;
            reg_gate_id  <= 32'd0;
            reg_t0       <= 128'd0;
            reg_t1       <= 128'd0;
            la_reg       <= 128'd0;
            lb_reg       <= 128'd0;
            wg_reg       <= 128'd0;
            we_reg       <= 128'd0;
        end else begin
            if (status_busy && !status_done) total_cycles <= total_cycles + 32'd1;

            case (state)
                ST_IDLE: begin
                    ram_we      <= 1'b0;
                    sha_start   <= 1'b0;
                    status_done <= 1'b0;
                    if (cmd_valid && cmd_ready) begin
                        status_busy   <= 1'b1;
                        cmd_ready     <= 1'b0;
                        reg_out_id    <= cmd_wire_out;
                        reg_in1_id    <= cmd_wire_in1;
                        reg_in2_id    <= cmd_wire_in2;
                        reg_gate_id   <= cmd_gate_id;
                        reg_t0        <= cmd_data_t0;
                        reg_t1        <= cmd_data_t1;
                        ram_rd_addr_a <= cmd_wire_in1;
                        ram_rd_addr_b <= cmd_wire_in2;

                        if (cmd_opcode == 8'h01) state <= ST_LOAD_EXEC;
                        else if (cmd_opcode == 8'h02) state <= ST_XOR_EXEC;
                        else if (cmd_opcode == 8'h03) state <= ST_AND_FETCH;
                        else if (cmd_opcode == 8'hFF) begin
                            ram_rd_addr_a <= cmd_wire_out;
                            state <= ST_DONE;
                        end
                    end else cmd_ready <= 1'b1;
                end

                ST_LOAD_EXEC: begin
                    ram_we      <= 1'b1;
                    ram_wr_addr <= reg_out_id;
                    ram_wr_data <= reg_t0;
                    cmd_ready   <= 1'b1;
                    status_busy <= 1'b0;
                    state       <= ST_IDLE;
                end

                ST_XOR_EXEC: begin
                    ram_we      <= 1'b1;
                    ram_wr_addr <= reg_out_id;
                    ram_wr_data <= xor_out;
                    cmd_ready   <= 1'b1;
                    status_busy <= 1'b0;
                    state       <= ST_IDLE;
                end

                ST_AND_FETCH: begin
                    la_reg <= ram_rd_data_a;
                    lb_reg <= ram_rd_data_b;
                    state  <= ST_AND_HASH_A;
                end

                ST_AND_HASH_A: begin
                    if (sha_ready) begin
                        sha_block <= {la_reg, reg_gate_id, 8'h80, 280'h0, 64'd160};
                        sha_start <= 1'b1;
                        state     <= ST_AND_WAIT_A;
                    end
                end

                ST_AND_WAIT_A: begin
                    sha_start <= 1'b0;
                    if (sha_done) begin
                        wg_reg <= (la_reg[0] == 1'b0) ? sha_digest[255:128] : (sha_digest[255:128] ^ reg_t0);
                        state  <= ST_AND_HASH_B;
                    end
                end

                ST_AND_HASH_B: begin
                    if (sha_ready) begin
                        sha_block <= {lb_reg, reg_gate_id, 8'h80, 280'h0, 64'd160};
                        sha_start <= 1'b1;
                        state     <= ST_AND_WAIT_B;
                    end
                end

                ST_AND_WAIT_B: begin
                    sha_start <= 1'b0;
                    if (sha_done) begin
                        we_reg <= (lb_reg[0] == 1'b0) ? sha_digest[255:128] : (sha_digest[255:128] ^ reg_t1 ^ la_reg);
                        state  <= ST_AND_FIN;
                    end
                end

                ST_AND_FIN: begin
                    ram_we      <= 1'b1;
                    ram_wr_addr <= reg_out_id;
                    ram_wr_data <= wg_reg ^ we_reg;
                    cmd_ready   <= 1'b1;
                    status_busy <= 1'b0;
                    state       <= ST_IDLE;
                end

                ST_DONE: begin
                    status_done  <= 1'b1;
                    status_busy  <= 1'b0;
                    cmd_ready    <= 1'b1;
                    status_match <= (ram_rd_data_a == reg_t0);
                    state        <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule

// ============================================================================
// 6. Testbench Mini Mandiri untuk Sandbox Web Peruri
// ============================================================================
