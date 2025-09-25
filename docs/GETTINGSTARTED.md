# Getting Started

This guide walks you from the code in this repo to a working **memoization** demonstration on a soft RISC-V core shell (the RTL provided here) and outlines how to integrate with a real softcore later.

---

## What you have in this repo

- **RTL**
  - `rtl/memotable_pkg.sv` — entry format & parameters.
  - `rtl/memounit.sv` — combinational memo table with two sample entries.
  - `rtl/regfile.sv` — 32×32 RV32 integer register file.
  - `rtl/core_top.sv` — minimal “core shell” that:
    - Samples `{x1=ra, x10=a0, x11=a1}`.
    - Looks up the **MemoUnit** using `(PC, ctx_hash)`.
    - On hit: writes memoized register results and sets `PC := next_pc`.
    - On miss: steps `PC += 4` (stand-in for “execute one insn”).
  - `rtl/tb/tb_core.sv` — a simple testbench with **two hits** and **one miss** scenario.
- **Tracer stubs**
  - `tracer/memogen.py` and `tracer/sample_entries.json` — illustrate how a tracer would serialize entries.
- **Docs**
  - Rationale, architecture, design, troubleshooting, and FAQs.

---

## Running the conceptual demo

The supplied testbench (`rtl/tb/tb_core.sv`) drives three scenarios:

1. **HIT A** — `PC=0x1000`, registers `(ra=0x2000, a0=5, a1=0)` → memo table returns:
   - Write `a0 := 12`, set `PC := 0x2000`.
2. **HIT B** — `PC=0x3000`, registers `(ra=0x4000, a0=3, a1=9)` → memo table returns:
   - Write `a0 := 42`, write `a1 := 77`, set `PC := 0x4000`.
3. **MISS** — `PC=0x1000`, but `a0` changed to `6` → context hash doesn’t match; PC increments by 4.

You should see (conceptually):
- After **HIT A**: `a0=12` and `PC=0x2000`, hit counter increments.
- After **HIT B**: `a0=42`, `a1=77`, and `PC=0x4000`, hit counter increments.
- After **MISS**: `PC=0x1004`, miss counter increments.

---

## How the memo table entries were chosen

The MVP hard-codes two entries inside `memounit.sv`. Each entry is keyed by:
- `start_pc` — where the sequence begins (here, placeholders `0x1000` and `0x3000`).
- `ctx_hash` — simple XOR of `{ra, a0, a1}` values.

On a match, the entry supplies:
- Up to **three** register write-backs (IDs + values).
- A **next_pc** (the destination after the sequence).

These are representative of the kind of pure “tiny handlers” you’d see after **indirect jumps** (`jalr`) or returns.

---

## Suggested next steps

1. **Swap in real entries**  
   Use your tracer to emit entries for your microbenchmarks. Mirror that data in `memounit.sv` or add an MMIO loader (see *Design* doc).

2. **Integrate with a real softcore (e.g., Ibex)**  
   - Hook the lookup at **fetch/decode** for PCs that begin memoizable regions.
   - On hit, **squash** in-flight younger stages, write memo results to the regfile, and set `PC := next_pc`.

3. **Benchmark**  
   Run tight loops with many indirect calls/returns to small handlers. Measure hit rate, IPC, and cycles saved with memoization **on vs. off**.

---

## Where to read next

- [ARCHITECTURE.md](./ARCHITECTURE.md) — how the parts connect.
- [DESIGN.md](./DESIGN.md) — assumptions, safety, replacement policy, and CSRs.
- [RESULTS.md](./RESULTS.md) — what to measure and what to expect.
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — common pitfalls.
- [FAQ.md](./FAQ.md) — quick answers.
