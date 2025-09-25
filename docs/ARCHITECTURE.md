# Architecture

The prototype demonstrates the **memoization path** around indirect jumps on a RISC-V softcore. The RTL here is a compact shell that isolates the memoization logic so you can later graft it onto Ibex/VexRiscv.

---

## Big picture

~~~mermaid
flowchart LR
  subgraph "Core Shell (RTL)"
    PC[PC Reg]
    RF[RegFile (x0..x31)]
    MU[MemoUnit<br/>(table lookup)]
  end
  TB[Tracer-produced Entries] --> MU

  PC -->|start_pc| MU
  RF -->|snapshot {ra,a0,a1}| MU
  MU -->|hit: wr_ids/vals,next_pc| RF
  MU -->|hit: next_pc| PC
  PC -->|miss: +4| PC
~~~

- **Inputs to lookup:** `(start_pc, ctx_hash(live_regs))`.
- **On hit:** apply up to 3 register writes and set `PC := next_pc` in one architectural step.
- **On miss:** proceed normally (here: `PC += 4` as a placeholder for “execute one instruction”).

---

## Interfaces

### MemoUnit (simplified)

~~~
Inputs:
  memo_enable                          : 1b
  req_valid                            : 1b
  req_start_pc                         : u32
  snap_x1_ra, snap_x10_a0, snap_x11_a1 : u32

Outputs:
  resp_hit                             : 1b
  resp_next_pc                         : u32
  resp_wr_mask                         : up to 3 bits (LSB-aligned)
  resp_wr_ids[3]                       : 3 × 5b
  resp_wr_vals[3]                      : 3 × u32
~~~

### Entry format (packed)

~~~
start_pc   : u32
ctx_hash   : u32
wr_mask    : 3b (LSB aligned)
wr_ids[3]  : 3 × 5b
wr_vals[3] : 3 × u32
next_pc    : u32
~~~

---

## Where this lives in a real softcore

- **Lookup site:** at **fetch/decode** when `PC` equals a memoizable region start.
- **Bypass action:** on hit, create a **macro-op** that:
  1. Writes the memoized register values to the regfile.
  2. Redirects the front-end to `next_pc`.
  3. **Squashes** any younger instructions to preserve precise state.
- **Learning path (future):** entries can be MMIO-loaded, CSR-controlled, and captured via a recorder for online learning.

---

## Timing notes

- MVP treats lookup as **combinational**; in a real core use a 1-cycle SRAM for the table and account for the additional branch redirect latency.
- The writebacks happen **atomically** relative to the PC redirect (same architectural moment).

---
