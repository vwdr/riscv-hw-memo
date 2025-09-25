// SPDX-License-Identifier: MIT
// memounit.sv — combinational memoization unit: lookup by (start_pc, ctx_hash),
// emit register writes and next_pc on a hit.
//
// NOTE (MVP): ctx_hash is a simple XOR of up to 3 "live" regs: x1 (ra), x10 (a0), x11 (a1).
// In a fuller design, the tracer and hardware agree on which live regs are sampled.

`timescale 1ns/1ps
import memotable_pkg::*;

module memounit #(
  parameter int NUM_ENTRIES = MEMO_NUM_ENTRIES,
  parameter int MAX_WRITES  = MEMO_MAX_WRITES
)(
  input  logic              clk,
  input  logic              rst,

  // Enable/disable memoization (CSR/strap)
  input  logic              memo_enable,

  // Lookup request at region start
  input  logic              req_valid,
  input  logic [31:0]       req_start_pc,

  // Live-reg snapshot (subset). For MVP we sample ra (x1), a0 (x10), a1 (x11).
  input  logic [31:0]       snap_x1_ra,
  input  logic [31:0]       snap_x10_a0,
  input  logic [31:0]       snap_x11_a1,

  // Lookup response
  output logic              resp_hit,
  output logic [31:0]       resp_next_pc,
  output logic [MAX_WRITES-1:0] resp_wr_mask,
  output logic [4:0]        resp_wr_ids  [MAX_WRITES],
  output logic [31:0]       resp_wr_vals [MAX_WRITES]
);

  // ---- Simple context hash (MVP): XOR of the 3 samples ----
  function automatic logic [31:0] ctx_hash_fn(
    input logic [31:0] ra,
    input logic [31:0] a0,
    input logic [31:0] a1
  );
    ctx_hash_fn = ra ^ a0 ^ a1;
  endfunction

  logic [31:0] req_ctx_hash;
  always_comb begin
    req_ctx_hash = ctx_hash_fn(snap_x1_ra, snap_x10_a0, snap_x11_a1);
  end

  // ---- Memo table storage (static for MVP; could be MMIO-loaded in a stretch) ----
  memo_entry_t table   [NUM_ENTRIES];

  // Initialize with two example entries illustrating the concept.
  // Entry 0: start_pc=0x00001000, context hash expected for (ra=0x00002000, a0=5, a1=0) => 0x00002005
  //          writes: a0 := 12, next_pc := ra (0x00002000)
  // Entry 1: start_pc=0x00003000, (ra=0x00004000, a0=3, a1=9) => 0x0000400A
  //          writes: a0 := 42, a1 := 77, next_pc := ra (0x00004000)
  // These are purely illustrative; in practice, a tracer emits many such entries.
  initial begin
    // Clear
    for (int i = 0; i < NUM_ENTRIES; i++) begin
      table[i].start_pc = '0;
      table[i].ctx_hash = '0;
      table[i].wr_mask  = '0;
      for (int j = 0; j < MAX_WRITES; j++) begin
        table[i].wr_ids[j]  = '0;
        table[i].wr_vals[j] = '0;
      end
      table[i].next_pc = '0;
    end

    // --- Entry 0 ---
    table[0].start_pc = 32'h0000_1000;
    table[0].ctx_hash = 32'h0000_2005;  // ra ^ a0 ^ a1 = 0x00002000 ^ 0x00000005 ^ 0x00000000
    table[0].wr_mask  = 3'b001;         // only wr[0] is valid
    table[0].wr_ids[0]= 5'd10;          // x10 (a0)
    table[0].wr_vals[0]=32'd12;         // memoized result: a0 becomes 12
    table[0].next_pc  = 32'h0000_2000;  // return to ra

    // --- Entry 1 ---
    table[1].start_pc = 32'h0000_3000;
    table[1].ctx_hash = 32'h0000_400A;  // 0x00004000 ^ 3 ^ 9 = 0x0000400A
    table[1].wr_mask  = 3'b011;         // wr[0] and wr[1]
    table[1].wr_ids[0]= 5'd10;          // x10 (a0)
    table[1].wr_vals[0]=32'd42;
    table[1].wr_ids[1]= 5'd11;          // x11 (a1)
    table[1].wr_vals[1]=32'd77;
    table[1].next_pc  = 32'h0000_4000;
  end

  // ---- Combinational lookup ----
  // On req_valid, search all entries; first match wins (lowest index priority).
  always_comb begin
    resp_hit      = 1'b0;
    resp_next_pc  = '0;
    resp_wr_mask  = '0;
    for (int k = 0; k < MAX_WRITES; k++) begin
      resp_wr_ids[k]  = '0;
      resp_wr_vals[k] = '0;
    end

    if (memo_enable && req_valid) begin
      for (int i = 0; i < NUM_ENTRIES; i++) begin
        if (!resp_hit &&
            table[i].start_pc == req_start_pc &&
            table[i].ctx_hash  == req_ctx_hash) begin
          resp_hit     = 1'b1;
          resp_next_pc = table[i].next_pc;
          resp_wr_mask = table[i].wr_mask;
          for (int j = 0; j < MAX_WRITES; j++) begin
            resp_wr_ids[j]  = table[i].wr_ids[j];
            resp_wr_vals[j] = table[i].wr_vals[j];
          end
        end
      end
    end
  end

endmodule
