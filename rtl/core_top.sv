// SPDX-License-Identifier: MIT
// core_top.sv — minimal RV32 "core shell" integrating MemoUnit.
// This is NOT a full ISA implementation. It demonstrates:
//  - sampling live regs (x1/x10/x11),
//  - looking up the MemoUnit at PC,
//  - on hit: bypass execution, perform up to 3 register writes, jump to next_pc,
//  - on miss: fall back to a "fake execute" (PC += 4).
//
// Stretch points are indicated where a real fetch/decoder/execute would sit.

`timescale 1ns/1ps
import memotable_pkg::*;

module core_top #(
  parameter int XLEN = 32
)(
  input  logic clk,
  input  logic rst,

  // Control/CSR-like inputs
  input  logic memo_enable,

  // Observation (for testbench)
  output logic [XLEN-1:0] dbg_pc,
  output logic [31:0]     dbg_hit_count,
  output logic [31:0]     dbg_miss_count,

  // Allow testbench to poke initial GPRs
  input  logic            tb_init_valid,
  input  logic [4:0]      tb_init_idx,
  input  logic [XLEN-1:0] tb_init_val
);

  // ——— PC register ———
  logic [XLEN-1:0] PC, PC_nxt;

  // ——— Register file ———
  logic        rf_we_a, rf_we_b;
  logic [4:0]  rf_wa_a, rf_wa_b;
  logic [31:0] rf_wd_a, rf_wd_b;

  logic [4:0]  ra0, ra1, ra2;
  logic [31:0] rd0, rd1, rd2;

  // Port A/B defaults
  assign rf_we_a = 1'b0;
  assign rf_we_b = 1'b0;
  assign rf_wa_a = '0;
  assign rf_wa_b = '0;
  assign rf_wd_a = '0;
  assign rf_wd_b = '0;

  // Read ports for x1/x10/x11 snapshots
  assign ra0 = 5'd1;   // x1 = ra
  assign ra1 = 5'd10;  // x10 = a0
  assign ra2 = 5'd11;  // x11 = a1

  regfile u_rf (
    .clk(clk), .rst(rst),
    .we_a(rf_we_a), .wa_a(rf_wa_a), .wd_a(rf_wd_a),
    .we_b(rf_we_b), .wa_b(rf_wa_b), .wd_b(rf_wd_b),
    .ra0(ra0), .ra1(ra1), .ra2(ra2), .rd0(rd0), .rd1(rd1), .rd2(rd2)
  );

  // testbench poke (write via Port B during init phase)
  // When tb_init_valid=1, write tb_init_idx := tb_init_val
  wire tb_poke = tb_init_valid;
  assign rf_we_b = tb_poke;
  assign rf_wa_b = tb_init_idx;
  assign rf_wd_b = tb_init_val;

  // ——— Memo unit ———
  logic              mu_hit;
  logic [31:0]       mu_next_pc;
  logic [MEMO_MAX_WRITES-1:0] mu_wr_mask;
  logic [4:0]        mu_wr_ids  [MEMO_MAX_WRITES];
  logic [31:0]       mu_wr_vals [MEMO_MAX_WRITES];

  memounit u_memo (
    .clk(clk), .rst(rst),
    .memo_enable(memo_enable),
    .req_valid(1'b1),                 // always check; entries restrict to specific PCs
    .req_start_pc(PC),
    .snap_x1_ra(rd0),
    .snap_x10_a0(rd1),
    .snap_x11_a1(rd2),
    .resp_hit(mu_hit),
    .resp_next_pc(mu_next_pc),
    .resp_wr_mask(mu_wr_mask),
    .resp_wr_ids(mu_wr_ids),
    .resp_wr_vals(mu_wr_vals)
  );

  // ——— Bypass writeback on hit ———
  // Map up to two writes in one cycle to the RF ports.
  // If there are 3 writes, perform the 3rd on the next cycle (MVP: we ignore that case here).
  logic [1:0] valid_cnt;
  always_comb begin
    valid_cnt = 2'd0;
    for (int i = 0; i < MEMO_MAX_WRITES; i++) begin
      if (mu_wr_mask[i]) valid_cnt++;
    end
  end

  // Assign port A (write 0) and port B (write 1) if present AND a hit occurred.
  logic        hit_we_a, hit_we_b;
  logic [4:0]  hit_wa_a, hit_wa_b;
  logic [31:0] hit_wd_a, hit_wd_b;

  always_comb begin
    hit_we_a = 1'b0; hit_we_b = 1'b0;
    hit_wa_a = '0;   hit_wa_b = '0;
    hit_wd_a = '0;   hit_wd_b = '0;

    if (mu_hit) begin
      // First write (if any)
      for (int i = 0; i < MEMO_MAX_WRITES; i++) begin
        if (mu_wr_mask[i]) begin
          hit_we_a = 1'b1;
          hit_wa_a = mu_wr_ids[i];
          hit_wd_a = mu_wr_vals[i];
          // find next one
          for (int j = i+1; j < MEMO_MAX_WRITES; j++) begin
            if (mu_wr_mask[j]) begin
              hit_we_b = 1'b1;
              hit_wa_b = mu_wr_ids[j];
              hit_wd_b = mu_wr_vals[j];
              break;
            end
          end
          break;
        end
      end
    end
  end

  // mux writes into RF ports (overriding tb_poke if both try; tb_init_valid should be low in run)
  assign rf_we_a = hit_we_a;
  assign rf_wa_a = hit_wa_a;
  assign rf_wd_a = hit_wd_a;

  // Port B is either TB poke or memo write #2 (memo has priority in run).
  assign rf_we_b = mu_hit ? hit_we_b : tb_poke;
  assign rf_wa_b = mu_hit ? hit_wa_b : tb_init_idx;
  assign rf_wd_b = mu_hit ? hit_wd_b : tb_init_val;

  // ——— PC update ———
  always_comb begin
    if (mu_hit) PC_nxt = mu_next_pc;      // bypass to next_pc
    else        PC_nxt = PC + 32'd4;      // fake "execute" of one instruction
  end

  // ——— Counters and PC reg ———
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      PC <= 32'h0000_0000;
      dbg_hit_count  <= '0;
      dbg_miss_count <= '0;
    end else begin
      PC <= PC_nxt;
      if (mu_hit) dbg_hit_count  <= dbg_hit_count  + 32'd1;
      else        dbg_miss_count <= dbg_miss_count + 32'd1;
    end
  end

  assign dbg_pc = PC;

endmodule
