# RISC-V Hardware Memoization (Softcore Prototype)

This MVP demonstrates **hardware memoization** on a soft RISC-V core shell:

- A memo unit looks up `(start_pc, ctx_hash(live_regs))`.
- On a **hit**, it **bypasses** execution: writes a few register results and updates `PC := next_pc`.
- On a **miss**, the core proceeds normally (in this MVP, we step `PC += 4` as a stand-in for execution).

> The tracer side (here, `tracer/memogen.py`) illustrates how entries could be produced.
> In a fuller build, you’d patch Spike/QEMU to detect memoizable regions and emit entries.

---

## What’s included

- `rtl/memotable_pkg.sv` — entry format & parameters
- `rtl/memounit.sv` — combinational lookup table with two example entries
- `rtl/regfile.sv` — 32×32 RV32 GPR file (x0 hardwired to 0)
- `rtl/core_top.sv` — small shell that integrates the memo unit and a PC
- `rtl/tb/tb_core.sv` — a testbench showing:
  - **Hit** at `PC=0x1000` with `ra=0x2000, a0=5, a1=0` → `a0=12`, `PC=0x2000`
  - **Hit** at `PC=0x3000` with `ra=0x4000, a0=3, a1=9` → `a0=42`, `a1=77`, `PC=0x4000`
  - **Miss** when the context hash doesn’t match

---

## How it maps to the research idea

- **Indirect jump entry:** PCs `0x1000` and `0x3000` stand in for targets reached via `jalr`/returns.
- **Live regs subset:** MVP samples `{ra (x1), a0 (x10), a1 (x11)}` and hashes them (XOR).
- **Memo payload:** up to **3 register writes** + **next_pc**.
- **Safety:** Entries correspond only to **pure, short** sequences; no memory/CSR/IO.

---

## Extending the MVP

- Replace the combinational table with an **MMIO-loadable** set-associative SRAM.
- Extend hashing to a configurable set of **live registers** (up to 4–8).
- Integrate into a real softcore (e.g., **Ibex**):
  - Lookup at fetch/ID on entry PCs.
  - On hit, **squash** younger stages, then perform writebacks and set `PC := next_pc`.
- Build a proper **tracer** (Spike/QEMU) to emit many entries from real code.

---

## Files at a glance

~~~text
riscv-hw-memo/
├─ rtl/
│  ├─ memotable_pkg.sv
│  ├─ memounit.sv
│  ├─ regfile.sv
│  ├─ core_top.sv
│  └─ tb/
│     └─ tb_core.sv
├─ tracer/
│  ├─ memogen.py
│  └─ sample_entries.json
├─ fw/
│  └─ benches/
│     └─ bench_ptrcall.c
└─ docs/
   └─ README.md
~~~

---

## Notes

This code is intentionally compact and annotated so you can port it into a bigger Ibex/VexRiscv flow later, swap in a real MMIO-backed memo table, and drive entries from a Spike/QEMU tracer.
