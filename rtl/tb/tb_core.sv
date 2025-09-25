// SPDX-License-Identifier: MIT
// tb_core.sv — simple testbench that demonstrates memo hits
// Scenario A: PC=0x1000, (ra=0x2000, a0=5, a1=0) -> memo hit: a0 becomes 12, PC jumps to 0x2000
// Scenario B: PC=0x3000, (ra=0x4000, a0=3, a1=9) -> memo hit: a0=42, a1=77, PC=0x4000
// Scenario C: PC=0x1000 but wrong a0 -> miss (for contrast)

`timescale 1ns/1ps
import memotable_pkg::*;

module tb_core;

  logic clk = 0;
  logic rst = 1;

  // DUT wires
  logic memo_enable;
  logic [31:0] dbg_pc;
  logic [31:0] dbg_hit_count, dbg_miss_count;

  // TB poke interface
  logic        tb_init_valid;
  logic [4:0]  tb_init_idx;
  logic [31:0] tb_init_val;

  core_top dut (
    .clk(clk),
    .rst(rst),
    .memo_enable(memo_enable),
    .dbg_pc(dbg_pc),
    .dbg_hit_count(dbg_hit_count),
    .dbg_miss_count(dbg_miss_count),
    .tb_init_valid(tb_init_valid),
    .tb_init_idx(tb_init_idx),
    .tb_init_val(tb_init_val)
  );

  // clock
  always #5 clk = ~clk; // 100 MHz nominal

  // helper: poke a GPR
  task poke_reg(input [4:0] idx, input [31:0] val);
  begin
    tb_init_idx   = idx;
    tb_init_val   = val;
    tb_init_valid = 1'b1;
    @(posedge clk);
    tb_init_valid = 1'b0;
    @(posedge clk);
  end
  endtask

  initial begin
    // reset
    memo_enable   = 1'b0;
    tb_init_valid = 1'b0;
    repeat (4) @(posedge clk);
    rst = 0;

    // Enable memoization
    memo_enable = 1'b1;

    // ----------------------
    // Scenario A (HIT)
    // ----------------------
    // Set PC=0x1000 and registers: ra=0x2000, a0=5, a1=0 (hash=0x2005)
    // Expect: a0 becomes 12, PC jumps to 0x2000, hit_count++.
    $display("\n[TB] Scenario A: expect HIT at PC=0x1000");
    // PC is 0 at reset; step it forward to 0x1000 by poking it via TB write port:
    // (we can't poke PC directly; we will "fast-forward" by 0x1000/4 cycles of misses would be slow)
    // Instead, we momentarily disable memo and assign PC by forcing dut.PC — but keep MVP simple:
    // We'll just set the DUT's PC through hierarchical reference for this TB demonstration.
    dut.PC = 32'h0000_1000;

    // Poke GPRs
    poke_reg(5'd1,  32'h0000_2000);  // ra
    poke_reg(5'd10, 32'd5);          // a0
    poke_reg(5'd11, 32'd0);          // a1

    @(posedge clk); // lookup
    @(posedge clk); // apply writes

    $display("[TB] A: PC=0x%08x, a0=%0d, hits=%0d, misses=%0d",
             dbg_pc, dut.u_rf.rf[10], dbg_hit_count, dbg_miss_count);

    // ----------------------
    // Scenario B (HIT)
    // ----------------------
    $display("\n[TB] Scenario B: expect HIT at PC=0x3000");
    dut.PC = 32'h0000_3000;
    poke_reg(5'd1,  32'h0000_4000);  // ra
    poke_reg(5'd10, 32'd3);          // a0
    poke_reg(5'd11, 32'd9);          // a1

    @(posedge clk);
    @(posedge clk);

    $display("[TB] B: PC=0x%08x, a0=%0d, a1=%0d, hits=%0d, misses=%0d",
             dbg_pc, dut.u_rf.rf[10], dut.u_rf.rf[11], dbg_hit_count, dbg_miss_count);

    // ----------------------
    // Scenario C (MISS)
    // ----------------------
    $display("\n[TB] Scenario C: expect MISS (wrong a0) at PC=0x1000");
    dut.PC = 32'h0000_1000;
    poke_reg(5'd1,  32'h0000_2000);
    poke_reg(5'd10, 32'd6);          // a0 changed to 6 → hash doesn't match 0x2005
    poke_reg(5'd11, 32'd0);

    @(posedge clk);
    @(posedge clk);

    $display("[TB] C: PC=0x%08x, a0=%0d, hits=%0d, misses=%0d",
             dbg_pc, dut.u_rf.rf[10], dbg_hit_count, dbg_miss_count);

    $display("\n[TB] Done.");
    $finish;
  end

endmodule
