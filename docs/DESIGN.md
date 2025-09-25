# Design

This document captures the **assumptions, constraints, and safety guards** for the memoization MVP, plus the path to a production-quality integration.

---

## Assumptions (MVP)

- ISA: **RV32I/M**, integer only (no FP).
- Sequences: straight-line (≤ 8 instructions), **pure** (no mem/CSR/IO), terminate before next control transfer.
- Live regs subset: `{ra (x1), a0 (x10), a1 (x11)}`; context hash = XOR(ra, a0, a1).  
  *(Future: support up to 8 configurable live regs; different hash.)*
- Effects payload: up to **3** register writebacks + `next_pc`.

---

## Correctness model

A **hit** replaces the execution of a short pure region with an **equivalent macro-op**:

1. Pre-state required to match: `PC == start_pc` and `ctx_hash(live_regs)`.
2. Macro-op effects: write `{(rd_i := val_i)}` and set `PC := next_pc`.
3. Architectural equivalence: all architecturally visible effects equal those of the skipped region.

**Non-goals:** reproducing microarchitectural timing; externally visible memory/IO/CSR side effects are **not** allowed in memoized regions for MVP.

---

## Safety guards

- **Whitelist** of allowed opcodes in tracer; reject sequences with loads/stores/CSRs/ECALL/EBREAK.
- **Interrupts/exceptions:** treat a memoized region as **atomic** (one macro-op). For early prototypes, run bare-metal microbenches or mask interrupts inside the region.
- **Context precision:** include all registers read-before-written in the live set; if uncertain, **don’t memoize** that slice.

---

## Table organization

- Size: 64–128 entries (MVP ships with 8 slots for simplicity).
- Associativity: 4-way recommended (MVP uses linear scan).
- Replacement: LRU (MVP uses first-match priority).
- Storage: small SRAM or registers; MMIO-loadable interface (future).

**MMIO map (proposed):**
- `CTRL.enable` (1b)
- `STATS.hits`, `STATS.misses`
- `ENTRY.write` window: program one entry at a time (fields serialized)

---

## Context hashing

- MVP hash: `ra ^ a0 ^ a1`.
- Future: a stronger mix (e.g., XOR-then-rotate across up to 8 regs) or a CRC-like fold; include optional **immediates** or **read-only memory values** when enabling idempotent loads.

---

## Pipeline integration (real core)

- Lookup at fetch/decode.
- On hit:
  - Assert a **bypass** signal.
  - **Squash** younger stages.
  - Send up to K writebacks into the architectural regfile ports.
  - Redirect front-end to `next_pc`.
- On miss: no side effects.

---

## CSRs & observability

- `mmoen` (enable), `mmohits`, `mmomisses`.
- Optional: `mmodebug` CSR to dump the last matched entry and its live context.
- Perf counters to capture sequence length distribution and hit rates.

---

## Stretch features

- **Online learning:** hardware recorder logs `(pc, live regs, results)` for miss/hot patterns; a host tool compiles them into entries.
- **Idempotent loads:** allow read-only loads by adding `(addr,val)` pairs to the context and payload.
- **Compiler assist:** LLVM pass annotates candidate regions; firmware exports a **MemoTable** section pre-baked into the binary.

