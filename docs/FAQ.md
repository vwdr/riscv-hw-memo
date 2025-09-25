# FAQ

**What is “hardware memoization” here?**  
Caching the **architectural effects** (register writes + next PC) of short, pure instruction sequences and replaying them as a single macro-op when the same **PC and context** recur.

**Why start at indirect jumps (`jalr`/returns)?**  
They frequently target tiny handlers (e.g., virtual dispatch, RPC stubs) that repeat with similar contexts—prime ground for memoization.

**Does this change program semantics?**  
No. Only **pure** regions are memoized. The macro-op’s writes and `next_pc` match what executing the skipped instructions would do.

**What about loads/stores, CSRs, or system calls?**  
Disallowed in the MVP’s memoized regions. Supporting idempotent loads is a future extension (by adding `(addr,val)` to the context/payload).

**How many registers can be written on a hit?**  
Three in the MVP (configurable). Increase write ports or stage over multiple cycles if needed.

**How big is the table?**  
Tiny (dozens to hundreds of entries). A 128-entry, 4-way set-associative table is a sensible starting point.

**What hash is used for context?**  
XOR of `{ra,a0,a1}` in the MVP for clarity. Replace with a stronger, configurable mix as you expand the live set.

**How do I populate entries?**  
Use a tracer (Spike or QEMU patch) to find pure sequences beginning at indirect jumps, compute live-reg context and results, then serialize entries for the hardware to load.

**Can this run on an FPGA softcore?**  
Yes. The MemoUnit is small and latency-tolerant. Start in simulation; then swap the combinational table for an MMIO-loadable SRAM and connect to Ibex/VexRiscv.

**What speedup should I expect?**  
On microbenches rich in tiny pure handlers: **1.1×–1.4×**. On mixed code, expect smaller gains.

**How does this relate to the CAL’24 memoization idea?**  
This prototype focuses on the **indirect-jump sequences** highlighted in that line of work, providing a tangible, end-to-end artifact (tracer → table → core) to study effectiveness and limitations.
