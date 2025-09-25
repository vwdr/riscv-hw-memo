# Results & Evaluation

This document defines what to measure, how to present it, and what outcomes to expect from the memoization MVP.

---

## Metrics

- **Hit rate**: `hits / (hits + lookups)`
- **Avg memoized length**: mean number of instructions per hit (from tracer)
- **Cycles saved**: `baseline_cycles – memo_cycles`
- **IPC**: instructions / cycles (both configurations)
- **Speedup**: `baseline_cycles / memo_cycles`
- **Overhead**: additional bubbles from lookup & redirect (should be ≤ 1 cycle per hit)

---

## Benchmarks

- **Micro A — pointer call**: indirect call to a tiny pure handler (`add/xor/and`), frequent repeats.
- **Micro B — virtual dispatch**: jump table with 8 small handlers, hot working set.
- **Micro C — toy RPC loop**: parse opcode, dispatch to tiny action, return.

For each benchmark:
1. Run **baseline** (memo disabled).
2. Run with **memo enabled** (preloaded entries).
3. Collect metrics above.

---

## Reporting templates

### Table: overall
| Benchmark | Hit Rate | Avg Len | Cycles (Base) | Cycles (Memo) | Speedup |
|-----------|---------:|--------:|--------------:|--------------:|--------:|
| Micro A   |   0.82   |   4.6   |     10,000,000|      7,600,000|   1.32× |
| Micro B   |   0.66   |   5.1   |      8,400,000|      7,200,000|   1.17× |
| Micro C   |   0.49   |   3.2   |     12,500,000|     11,300,000|   1.11× |

*(Numbers are illustrative placeholders; replace with your measurements.)*

### Figure ideas
- **Hit rate vs. handler size** (bar chart).
- **Speedup vs. average sequence length** (scatter).
- **IPC breakdown** (stacked bars) baseline vs. memo.

---

## Expected outcomes (honest forecast)

- **Hit rate:** 60–95% on crafted microbenches rich in indirect tiny handlers; lower on mixed code.
- **Sequence length:** 3–8 instructions typical.
- **Speedup:** ~**1.1×–1.4×** on microbenches; ~≤**1.1×** on mixed workloads without many memoizable regions.
- **Sensitivity:** benefits scale with:
  - Frequency of indirect jumps into tiny pure code.
  - Predictability of the live-reg context (few distinct values).
  - Table capacity & replacement behavior.

---

## Notes & caveats

- Memoization covers **pure** regions only; any memory/CSR side effect disqualifies a region.
- Redirect latency and regfile write port pressure limit peak gains; keep the memo action a **single architectural step**.
- For fair comparisons, keep clock, memory system, and toolchain constant between runs.

