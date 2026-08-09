# Montgomery Modular Exponentiation with Karatsuba Multiplier

## Problem
Implement modular exponentiation `C = A^E mod N` in hardware — with the constraint that
Verilog's built-in `*`, `/`, and `%` operators are **not allowed** anywhere in the design
path (except explicitly noted below). Every arithmetic primitive has to be built from
adders/shifters and the algorithms below.

## Approach
Five building blocks, composed bottom-up:

- **`karatsuba_mul.v`** — recursive multiplier: splits each operand into high/low halves and
  reduces one multiplication to three (`z0`, `z2`, `z1 = (x_low+x_high)(y_low+y_high) - z0 - z2`)
  instead of the schoolbook four. Recurses down to a `BASE_WIDTH`-bit base case. **The one
  intentional use of `*` in the whole design** is at that base case — recursion has to bottom
  out somewhere, and the assignment permits the multiply operator there; everything above the
  base case is built from the Karatsuba recombination instead.
- **`non_restoring_div.v`** — bit-serial non-restoring division, used both as a standalone
  divider and inside the Montgomery setup to compute `N mod R` and related reductions.
- **`extended_gcd.v`** — binary/bit-serial extended Euclidean algorithm, computing `gcd(a,b)`
  and the Bézout coefficients.
- **`modular_inverse.v`** — wraps `extended_gcd` to compute `a⁻¹ mod m`; used here to find
  `N⁻¹ mod R` (needed for Montgomery's `N' = -N⁻¹ mod R`).
- **`montgomery_mul.v`** — computes `a·b·R⁻¹ mod N` using `karatsuba_mul` for the two internal
  multiplications (`a·b` and `m·N`) and an addition/shift reduction step — this is the
  operation repeated at every step of the exponentiation.
- **`montgomery_exp_top.v`** — top-level FSM implementing Square-and-Multiply: converts `A`
  into Montgomery form, then for each bit of `E` (MSB to LSB) does a Montgomery square and
  conditionally a Montgomery multiply, finishing with a conversion back out of Montgomery form.

## Key result
`tb_montgomery_exp_top.v` verifies full `A^E mod N` against expected results; `tb_karatsuba_mul.v`
and `tb_non_restoring_div.v` verify those primitives independently. `extended_gcd` and
`modular_inverse` don't have standalone testbenches — they're exercised indirectly through the
top-level exponentiation testbench.

## What I'd do differently
Give `extended_gcd`/`modular_inverse` their own direct testbenches rather than relying on the
top-level test to exercise them — a bug isolated to the GCD step would currently be harder to
localize than it should be.

## Files
```
rtl/
├── karatsuba_mul.v        — recursive Karatsuba multiplier
├── non_restoring_div.v    — bit-serial non-restoring divider
├── extended_gcd.v         — extended Euclidean algorithm (gcd + Bézout coefficients)
├── modular_inverse.v      — a⁻¹ mod m, built on extended_gcd
├── montgomery_mul.v       — a·b·R⁻¹ mod N, built on karatsuba_mul
└── montgomery_exp_top.v   — top-level Square-and-Multiply FSM (A^E mod N)
tb/
├── tb_karatsuba_mul.v
├── tb_non_restoring_div.v
└── tb_montgomery_exp_top.v
```

## How to run
```bash
iverilog -o sim tb/tb_montgomery_exp_top.v rtl/*.v && vvp sim
```
