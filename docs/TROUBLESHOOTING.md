# Troubleshooting

Common issues and how to reason about them in the memoization MVP.

---

## No memo hits occur

- **PC mismatch**: Ensure the entry’s `start_pc` exactly matches the tested PC.
- **Context mismatch**: The XOR hash must match the runtime values of `{ra, a0, a1}`.
- **Memo disabled**: Confirm the `memo_enable` input is asserted (in the testbench or core CSR).

---

## Hits occur but register values aren’t written

- **Write mask**: Check `wr_mask` bits in the entry (each 1 enables a corresponding write).
- **x0 writes ignored**: Writes to `x0` are discarded by design; ensure you’re not targeting reg 0.
- **Port limits**: MVP maps up to two writes in one cycle; a third write would need a second cycle in a fuller design.

---

## PC doesn’t jump to the expected address

- **next_pc field**: Verify the entry’s `next_pc`.
- **Overwrites**: Ensure no other PC update path overrides the redirect (in the MVP, `mu_hit` wins).

---

## Spurious hits (false positives)

- **Hash collision**: XOR is simple; use more live regs or a stronger mix if needed.
- **Entry hygiene**: Make sure unused table slots are zeroed.

---

## Integrating into a real core

- **Squash logic**: Ensure a hit squashes younger pipeline stages to keep precise state.
- **Timing**: If memo table is an SRAM, budget a cycle for lookup; redirect timing must fit your branch unit.

---

## Debugging tips

- Instrument counters: `hits`, `misses`, `avg_len`.
- Trace `(PC, ra, a0, a1)` at lookup time and compare with entry fields.
- Log writebacks `(rd, val)` when `resp_wr_mask[i]=1`.
