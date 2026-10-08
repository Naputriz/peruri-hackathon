// ============================================================================
// File: src/garble_gate_fsm.v
// Module: garble_gate_fsm
// Description: FSM Controller for Yao's Garbled Circuit Evaluation
//              Supports Free-XOR (0-cycle) & Half-Gates AND (SHA-256 PRF)
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

    // Gate Command Interface
    input          cmd_valid;
    output         cmd_ready;
    reg            cmd_ready;
    input  [7:0]   cmd_opcode;      // 0x01: LOAD, 0x02: XOR, 0x03: AND, 0xFF: FINISH
    input  [7:0]   cmd_wire_out;
    input  [7:0]   cmd_wire_in1;
    input  [7:0]   cmd_wire_in2;
    input  [31:0]  cmd_gate_id;
    input  [127:0] cmd_data_t0;     // Wire label for LOAD / TG for AND / Exp label for FINISH
    input  [127:0] cmd_data_t1;     // TE for AND

    // Status & Evaluation Results
    output         eval_busy;
    reg            eval_busy;
    output         eval_done;
    reg            eval_done;
    output         match_result;
    reg            match_result;
    output [31:0]  cycle_counter;
    reg    [31:0]  cycle_counter;

    // SHA-256 Core Interface
    output         sha_start;
    reg            sha_start;
    output [511:0] sha_block;
    reg    [511:0] sha_block;
    input          sha_ready;
    input          sha_done;
    input  [255:0] sha_digest;

    // Wire Label RAM Interface
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

    // Free-XOR Unit Interface
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

    // Internal registers holding current gate parameters
    reg [7:0]   reg_out_id;
    reg [7:0]   reg_in1_id;
    reg [7:0]   reg_in2_id;
    reg [31:0]  reg_gate_id;
    reg [127:0] reg_t0;
    reg [127:0] reg_t1;

    // Registers storing fetched wire labels A and B
    reg [127:0] label_a_reg;
    reg [127:0] label_b_reg;
    reg [127:0] wg_reg;
    reg [127:0] we_reg;

    // Direct connections to Free-XOR unit
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
            // Count clock cycles while busy (benchmarking)
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

                        // Set RAM read addresses for wire inputs
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

                // 1. Execute LOAD_WIRE
                ST_LOAD_EXEC: begin
                    ram_we      <= 1'b1;
                    ram_wr_addr <= reg_out_id;
                    ram_wr_data <= reg_t0;
                    cmd_ready   <= 1'b1;
                    eval_busy   <= 1'b0;
                    state       <= ST_IDLE;
                end

                // 2. Execute EVAL_XOR (Free-XOR, 0 Cycles)
                ST_XOR_EXEC: begin
                    ram_we      <= 1'b1;
                    ram_wr_addr <= reg_out_id;
                    ram_wr_data <= xor_out;
                    cmd_ready   <= 1'b1;
                    eval_busy   <= 1'b0;
                    state       <= ST_IDLE;
                end

                // 3. Dispatch for Half-Gates AND Evaluation
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

                // 6. Half-Gates AND Finalization: W_out = W_G ^ W_E
                ST_AND_FINALIZE: begin
                    ram_we      <= 1'b1;
                    ram_wr_addr <= reg_out_id;
                    ram_wr_data <= wg_reg ^ we_reg;
                    cmd_ready   <= 1'b1;
                    eval_busy   <= 1'b0;
                    state       <= ST_IDLE;
                end

                // 7. Complete Circuit Evaluation (FINISH)
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
