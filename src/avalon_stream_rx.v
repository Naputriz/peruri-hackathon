// ============================================================================
// File: src/avalonstreamrx.v
// Module: avalonstreamrx
// Description: Avalon-MM Slave / FIFO Bridge interface for ARM Cortex-A9 HPS
//              Connects HPS Linux Driver with GarbleChip FPGA Accelerator
//              According to DE10-Nano SoC Architecture (Intel Cyclone V 5CSEBA6U23I7)
// ============================================================================

timescale 1ns / 1ps

module avalonstreamrx (
    input  wire         clk,
    input  wire         rst_n,

    // Avalon-MM Slave Interface (from HPS-to-FPGA Lightweight Bridge)
    input  wire [5:0]   avs_address,
    input  wire         avs_read,
    output reg  [31:0]  avs_readdata,
    input  wire         avs_write,
    input  wire [31:0]  avs_writedata,
    output wire         avs_waitrequest,

    // Control interface to GarbleChip Top IP Core
    output reg          cmd_valid,
    input  wire         cmd_ready,
    output reg  [7:0]   cmd_opcode,
    output reg  [7:0]   cmdwireout,
    output reg  [7:0]   cmdwirein1,
    output reg  [7:0]   cmdwirein2,
    output reg  [31:0]  cmdgateid,
    output reg  [127:0] cmddatat0,
    output reg  [127:0] cmddatat1,

    // Status feedback from GarbleChip
    input  wire         status_busy,
    input  wire         status_done,
    input  wire         status_match,
    input  wire [31:0]  total_cycles
);

    assign avswaitrequest = cmdvalid && !cmd_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_valid     &lt;= 1'b0;
            cmd_opcode    &lt;= 8'd0;
            cmdwireout  &lt;= 8'd0;
            cmdwirein1  &lt;= 8'd0;
            cmdwirein2  &lt;= 8'd0;
            cmdgateid   &lt;= 32'd0;
            cmddatat0   &lt;= 128'd0;
            cmddatat1   &lt;= 128'd0;
            avs_readdata  &lt;= 32'd0;
        end else begin
            // Handshake valid auto-clear after accepted by core
            if (cmdvalid && cmdready) begin
                cmd_valid &lt;= 1'b0;
            end

            // Register write from ARM HPS
            if (avs_write) begin
                case (avs_address)
                    6'h00: begin
                        // Address 0x00: Gate Execution Trigger (Opcode & Valid)
                        cmdopcode &lt;= avswritedata[7:0];
                        cmd_valid  &lt;= 1'b1;
                    end
                    6'h01: begin
                        // Address 0x01: Wire Index {dst, src1, src2}
                        cmdwireout &lt;= avs_writedata[31:24];
                        cmdwirein1 &lt;= avs_writedata[23:16];
                        cmdwirein2 &lt;= avs_writedata[15:8];
                    end
                    6'h02: begin
                        // Address 0x02: Gate Identity (Gate ID)
                        cmdgateid &lt;= avs_writedata;
                    end
                    // Address 0x04..0x07: Garbled Table T0 / Input Label (128-bit)
                    6'h04: cmddatat0[127:96] &lt;= avs_writedata;
                    6'h05: cmddatat0[95:64]  &lt;= avs_writedata;
                    6'h06: cmddatat0[63:32]  &lt;= avs_writedata;
                    6'h07: cmddatat0[31:0]   &lt;= avs_writedata;
                    // Address 0x08..0x0B: Garbled Table T1 / TE (128-bit)
                    6'h08: cmddatat1[127:96] &lt;= avs_writedata;
                    6'h09: cmddatat1[95:64]  &lt;= avs_writedata;
                    6'h0A: cmddatat1[63:32]  &lt;= avs_writedata;
                    6'h0B: cmddatat1[31:0]   &lt;= avs_writedata;
                    default: ;
                endcase
            end

            // Status & Benchmark read by ARM HPS
            if (avs_read) begin
                case (avs_address)
                    6'h10: avsreaddata &lt;= {28'd0, statusmatch, statusdone, statusbusy, cmd_ready};
                    6'h11: avsreaddata &lt;= totalcycles;
                    default: avs_readdata &lt;= 32'd0;
                endcase
            end
        end
    end

endmodule