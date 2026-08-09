# Two-Key Triple DES: Single-Cycle, Multi-Cycle & Pipelined Hardware Implementations

A from-scratch Verilog implementation of **Two-Key Triple DES** (`C = E_K1(D_K2(E_K1(P)))`) supporting three block-cipher modes of operation — **ECB**, **CBC**, and **OFB** — realized in three distinct microarchitectural styles: single-cycle, multi-cycle (FSM-driven), and a fully pipelined datapath. Built as a digital systems design exercise and extended beyond the original scope to explore correctness pitfalls that only surface under pipeline hazards.

## Why this repo is here

Most student DES implementations stop at "the testbench passes." This one didn't stop there: the pipelined version initially passed every provided testbench while still not being a *true* pipeline — it could stream blocks within a single message but silently forced a full pipeline drain between messages, so back-to-back throughput was no better than the multi-cycle design. Finding and fixing that (see [`pipeline/`](#pipeline--the-interesting-part) below) is the part of this project I'm most glad happened, because it's the kind of bug that only shows up once you think about the design at the level of overlapping operations rather than single test vectors — which is exactly the kind of scrutiny real pipelined hardware demands.

## Repository structure

```
.
├── singlecycle/
│   ├── rtl/     # Combinational Two-Key 3DES: full 48-round datapath in one cycle
│   └── tb/
├── multicycle/
│   ├── rtl/     # FSM-driven: one DES round per clock, 48 cycles/block, one block at a time
│   └── tb/
└── pipeline/
    ├── rtl/     # 48-stage systolic pipeline: new block accepted every clock cycle
    └── tb/
```

Each variant implements the same architectural spec (`clk`, `nrst`, `start`, `mode[1:0]`, `data_in[255:0]`, `key[127:0]`, `iv[63:0]` → `data_out[255:0]`, `done`, `busy`) and shares the same core combinational primitives (`IP`, `IP_inv`, `E`, `P`, `PC1`, `PC2`, `S1`–`S8`), so the three folders are directly comparable in area/latency/throughput trade-offs.

## Architecture summary

| Design | Latency / block | Throughput | Key idea |
|---|---|---|---|
| **Single-cycle** | 1 clock | 1 block / N cycles (N = combinational delay) | All 48 DES rounds (3 × 16) unrolled as pure combinational logic. Simple, but clock period is bounded by the full 3DES critical path. |
| **Multi-cycle** | 48 clocks | 1 block / 48 cycles | One `DES_round_step` reused every cycle, key schedule advanced by a `key_pipe_stage` per cycle. Small area, short critical path, but the datapath sits idle 47/48 of the time per block. |
| **Pipeline** | 48 clocks (fixed latency) | **1 block / cycle** (steady state) | Three chained 16-stage systolic engines (`E_K1 → D_K2 → E_K1`), each stage carrying its own `(L, R, C, D, valid)` token so multiple blocks are in flight simultaneously with zero data-hazard between them. |

### `pipeline/` — the interesting part

The per-round pipeline stages (`TripleDES_pipe.v`) are genuinely hazard-free: each of the 16 stages in every engine is a dedicated register slot whose combinational logic only reads the *previous* stage's registers, so two blocks occupying different stages can never corrupt one another — this is standard systolic-array correctness and held up under RTL trace-through.

The bug lived one level up, in the top-level controller (`TopPipe.v`): the FSM gated acceptance of a new `start` on **full drain** of the previous message (`blk_done_count == NUM_BLOCKS-1`) rather than on **completion of feeding** the previous message's blocks into the pipe. Since every block has identical fixed latency through the three chained engines, and blocks are always fed strictly in order, a message's outputs are guaranteed to be fully collected before the next message's outputs can arrive — so a new message can safely start feeding the instant the old one finishes feeding, using the same output buffer with no risk of collision. The fix decouples the feed-side FSM from the collect-side FSM and exposes a `ready` signal asserted one cycle before the last block of the current message is fed, letting the caller pipeline consecutive `start` commands with zero gap instead of waiting out the full ~48-cycle drain.

This turns the effective inter-message latency from *feed time + full pipeline depth* down to *feed time*, which is the actual throughput benefit a "pipeline" is supposed to deliver — and it's a correctness property that a single-message testbench structurally cannot expose, which is exactly why the original version passed all its tests while still not being a true pipeline.

## Verification

- Per-module unit tests for `IP`/`IP_inv`/`E`/`P`/`PC1`/`PC2`/S-boxes/`DES_round_step`/`key_pipe_stage`.
- Full-mode testbenches (`test_single`, `test_multi`, `test_pipe`, and their `_padd` counterparts for non-block-aligned input) exercising ECB/CBC/OFB against known-good vectors.
- Padding correctness checks for input widths that aren't multiples of 64 bits.
- Back-to-back multi-message pipeline testbench to empirically confirm the `ready`-gated overlap in `pipeline/` behaves as analyzed above.

## Skills demonstrated

RTL design across three microarchitectural paradigms of the same algorithm; FSM design; systolic pipeline design with per-stage hazard reasoning; identifying and fixing a correctness/throughput bug that survived a full passing test suite by reasoning about the design's behavior *outside* the cases the tests covered; testbench design for block-cipher modes of operation.


---
*Originally built for a digital systems design course; extended independently to explore microarchitectural correctness beyond the assignment's test coverage.*








