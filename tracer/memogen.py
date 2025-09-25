# SPDX-License-Identifier: MIT
# memogen.py — illustrative "tracer" that emits memo entries for specific contexts.
# This is a toy generator that mirrors the two hardcoded examples inside memounit.sv.
#
# It shows how a real tracer would serialize entries (start_pc + ctx_hash + writes + next_pc).
#
# NOTE: This script is illustrative; you don't need to run it inside VS Code Web.
# It mirrors the JSON schema in sample_entries.json.

import json
from typing import List, Dict

def ctx_hash(ra: int, a0: int, a1: int) -> int:
    return (ra ^ a0 ^ a1) & 0xFFFFFFFF

def entry(start_pc: int, ra: int, a0: int, a1: int,
          writes: List[Dict[str, int]], next_pc: int):
    return {
        "start_pc": start_pc,
        "ctx_hash": ctx_hash(ra, a0, a1),
        "writes": writes,   # list of {"reg": <int 0..31>, "val": <u32>}
        "next_pc": next_pc
    }

entries = [
    entry(0x00001000, ra=0x00002000, a0=5, a1=0,
          writes=[{"reg": 10, "val": 12}],
          next_pc=0x00002000),
    entry(0x00003000, ra=0x00004000, a0=3, a1=9,
          writes=[{"reg": 10, "val": 42}, {"reg": 11, "val": 77}],
          next_pc=0x00004000),
]

with open("sample_entries.json", "w") as f:
    json.dump({"entries": entries}, f, indent=2)
