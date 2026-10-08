// ============================================================================
// File: src/avalon_stream_rx.v
// Module: avalon_stream_rx
// Description: Antarmuka Avalon-MM Slave / FIFO Bridge untuk ARM Cortex-A9 HPS
//              Menghubungkan HPS Linux Driver dengan Akselerator GarbleChip FPGA
//              Sesuai Arsitektur DE10-Nano SoC (Intel Cyclone V 5CSEBA6U23I7)
// ============================================================================

`timescale 1ns / 1ps

module avalon_stream_rx (
    input  wire         clk,
    input  wire         rst_n,

    // Avalon-MM Slave Interface (dari HPS-to-FPGA Lightweight Bridge)
    input  wire [5:0]   avs_address,
    input  wire         avs_read,
    output reg  [31:0]  avs_readdata,
    input  wire         avs_write,
    input  wire [31:0]  avs_writedata,
    output wire         avs_waitrequest,

    // Antarmuka Kontrol ke GarbleChip Top IP Core
    output reg          cmd_valid,
    input  wire         cmd_ready,
    output reg  [7:0]   cmd_opcode,
    output reg  [7:0]   cmd_wire_out,
    output reg  [7:0]   cmd_wire_in1,
    output reg  [7:0]   cmd_wire_in2,
    output reg  [31:0]  cmd_gate_id,
    output reg  [127:0] cmd_data_t0,
    output reg  [127:0] cmd_data_t1,

    // Status Feedback dari GarbleChip
    input  wire         status_busy,
    input  wire         status_done,
    input  wire         status_match,
    input  wire [31:0]  total_cycles
);

    assign avs_waitrequest = cmd_valid && !cmd_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_valid     <= 1'b0;
            cmd_opcode    <= 8'd0;
            cmd_wire_out  <= 8'd0;
            cmd_wire_in1  <= 8'd0;
            cmd_wire_in2  <= 8'd0;
            cmd_gate_id   <= 32'd0;
            cmd_data_t0   <= 128'd0;
            cmd_data_t1   <= 128'd0;
            avs_readdata  <= 32'd0;
        end else begin
            // Handshake valid auto-clear setelah diterima oleh core
            if (cmd_valid && cmd_ready) begin
                cmd_valid <= 1'b0;
            end

            // Penulisan Register dari ARM HPS
            if (avs_write) begin
                case (avs_address)
                    6'h00: begin
                        // Alamat 0x00: Trigger Eksekusi Gerbang (Opcode & Valid)
                        cmd_opcode <= avs_writedata[7:0];
                        cmd_valid  <= 1'b1;
                    end
                    6'h01: begin
                        // Alamat 0x01: Indeks Kawat {dst, src1, src2}
                        cmd_wire_out <= avs_writedata[31:24];
                        cmd_wire_in1 <= avs_writedata[23:16];
                        cmd_wire_in2 <= avs_writedata[15:8];
                    end
                    6'h02: begin
                        // Alamat 0x02: Identitas Gerbang (Gate ID)
                        cmd_gate_id <= avs_writedata;
                    end
                    // Alamat 0x04..0x07: Garbled Table T0 / Input Label (128-bit)
                    6'h04: cmd_data_t0[127:96] <= avs_writedata;
                    6'h05: cmd_data_t0[95:64]  <= avs_writedata;
                    6'h06: cmd_data_t0[63:32]  <= avs_writedata;
                    6'h07: cmd_data_t0[31:0]   <= avs_writedata;
                    // Alamat 0x08..0x0B: Garbled Table T1 / TE (128-bit)
                    6'h08: cmd_data_t1[127:96] <= avs_writedata;
                    6'h09: cmd_data_t1[95:64]  <= avs_writedata;
                    6'h0A: cmd_data_t1[63:32]  <= avs_writedata;
                    6'h0B: cmd_data_t1[31:0]   <= avs_writedata;
                    default: ;
                endcase
            end

            // Pembacaan Status & Benchmark oleh ARM HPS
            if (avs_read) begin
                case (avs_address)
                    6'h10: avs_readdata <= {28'd0, status_match, status_done, status_busy, cmd_ready};
                    6'h11: avs_readdata <= total_cycles;
                    default: avs_readdata <= 32'd0;
                endcase
            end
        end
    end

endmodule
