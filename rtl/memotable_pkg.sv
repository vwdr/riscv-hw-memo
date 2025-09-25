// SPDX-License-Identifier: MIT
// memotable_pkg.sv — parameters and entry format for the memoization table.

package memotable_pkg;

  // Tunables for the memo table.
  parameter int MEMO_NUM_ENTRIES = 8;   // MVP: tiny, associative table of fixed size
  parameter int MEMO_MAX_WRITES  = 3;   // how many register writes a memo can carry

  // RISC-V encoding sizes (RV32)
  parameter int XLEN = 32;
  parameter int REGW = 5;               // register index width for 32 GPRs

  // A single memo entry: match (start_pc, ctx_hash) and, on hit, perform up to 3 writes + jump.
  typedef struct packed {
    logic [XLEN-1:0] start_pc;                    // target PC where region begins
    logic [XLEN-1:0] ctx_hash;                    // hash of selected live regs (see memo unit)
    logic [MEMO_MAX_WRITES-1:0] wr_mask;         // which of wr_ids/vals are valid (LSB-aligned)
    logic [REGW-1:0]           wr_ids [MEMO_MAX_WRITES];  // registers to write (x1..x31)
    logic [XLEN-1:0]           wr_vals[MEMO_MAX_WRITES];  // values to write
    logic [XLEN-1:0] next_pc;                     // next PC after memoized region ("bypass to")
  } memo_entry_t;

endpackage