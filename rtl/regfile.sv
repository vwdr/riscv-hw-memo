// SPDX-License-Identifier: MIT
// regfile.sv — simple RV32 register file with 32 x 32b GPRs, x0 is hardwired to 0.
// Two write ports (for future expansion), one read port array (MVP: 3 reads for snapshots).

`timescale 1ns/1ps
module regfile #(
  parameter int XLEN = 32,
  parameter int NUMREG = 32
)(
  input  logic              clk,
  input  logic              rst,

  // Write port A
  input  logic              we_a,
  input  logic [4:0]        wa_a,
  input  logic [XLEN-1:0]   wd_a,

  // Write port B (optional use)
  input  logic              we_b,
  input  logic [4:0]        wa_b,
  input  logic [XLEN-1:0]   wd_b,

  // Random-access reads (combinational)
  input  logic [4:0]        ra0, ra1, ra2,
  output logic [XLEN-1:0]   rd0, rd1, rd2
);

  logic [XLEN-1:0] rf[NUMREG-1:0];

  // Reset: zero the register file except x0 (already zero).
  integer i;
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (i = 0; i < NUMREG; i++) begin
        rf[i] <= '0;
      end
    end else begin
      if (we_a && (wa_a != 5'd0)) rf[wa_a] <= wd_a;
      if (we_b && (wa_b != 5'd0)) rf[wa_b] <= wd_b;
      rf[0] <= '0; // keep x0 at zero
    end
  end

  // Combinational reads
  assign rd0 = (ra0 == 5'd0) ? '0 : rf[ra0];
  assign rd1 = (ra1 == 5'd0) ? '0 : rf[ra1];
  assign rd2 = (ra2 == 5'd0) ? '0 : rf[ra2];

endmodule
