# Q5 — Physical register file size and register class (35 pts)

## Idea
Same loop as Q4, but every filler instruction **writes a register**. Every in-flight
register write holds a physical register until it retires. If the physical registers
run out before the ROB does, the knee moves to a smaller N. The knee position then
gives the number of *free* physical registers of that class.

Filler choices:
- `int`: `add %rX, %rX` rotating over 10 integer registers. This is not a zeroing
  idiom and not a `mov`, so rename cannot eliminate it, and each chain is short
  (2N/10), so it never becomes the bottleneck.
- `ymm`: `vpaddd %ymm0, %ymm0, %ymmK` writes ymm1..15. Every instruction is
  independent because ymm0 is never written.
- `mix`: alternating `int` / `ymm`. If the two classes share **one** register file, the
  knee stays at ≈ the smaller single-class knee. If they are **separate**, each file
  fills at half the rate and the knee moves to ≈ 2× the int knee, capped by the ROB.

Avoided: `xor r,r` / `vpxor` zeroing idioms and `mov r,r`. Both can be handled at rename
without allocating a register.

## Implementation
The same harness as Q2/Q4 (`common/chase/`), generated with
`--kinds int,ymm,mix --n 0:640:8`.

| File | What it does |
|---|---|
| `bench/Makefile` | Generates `kernels.S`, links `q5_bench`. |
| `plots/plot.py` | One panel per result file: int / ymm / mix curves plus Q4's NOP curve as a dashed reference (if Q4 results exist for the same host/mode). |

Code snippet (`int` filler, N = 3):
```asm
1:  mov (%rax), %rax       # miss A
    add %r8, %r8           # each writes a fresh physical register
    add %r9, %r9
    add %r10, %r10
    mov (%rcx), %rcx       # miss B
    ...
```

## How to run
```bash
cd q05_prf/bench
./run.sh native 2           # ~15 s
./run.sh sgx 2              # same driver; kernels + data inside an SGX enclave
python3 ../plots/plot.py    # -> plots/q5_prf.png + knees on stdout
```
Run Q4 first if you want the NOP reference line on the plot.

## Interpreting results
- Knee(int) < knee(NOP) → the integer PRF limits the window before the ROB does.
  Free int registers ≈ N_knee + 1, because load A also writes a register. Total PRF ≈
  free + architectural state held by committed values (16 GPRs plus internal and
  flag-related registers). Report it as a lower bound.
- Knee(ymm) gives the same for the vector PRF.
- Knee(mix) ≈ 2 × knee(int) → integer and vector are **separate register classes**.
- Native vs SGX: knee positions should match.

## Baseline (artemisia, native, CPU 2, 11 trials)
| filler | jump between | reading |
|---|---|---|
| nop (Q4) | 496 → 504 | ROB |
| int | 208 → 216 | ~210 free integer registers |
| ymm | 240 → 248 | ~245 free vector registers |
| mix | 424 → 432 | ≈ 2× int knee → separate int / vector files |

The published Golden Cove int PRF is 280 entries, but the measured knee is ~210. The gap is
larger than the 16 architectural GPRs. Open questions to test before writing up:
1. **Flags:** do `add` (which writes flags) and a flags-free writer such as `lea`
   or `shlx` give the same knee?
2. **Rotation width:** try more filler registers.
3. **Unrelated limits:** check that it isn't the scheduler or another structure by
   making the filler `int` chains even shorter.

Also consider `zmm` filler (AVX-512 is available on this CPU) as a further class check.

**SGX enclave (same machine, 11 trials):** int 208 → 216 and mix 424 → 432, identical to native. ymm 256 → 264, a clean step; natively the ymm transition is ragged across 240–272 (a repeat run gave 460, 593, 494, 677, 794 cycles at N = 240…272). So the two overlap. Run a step-1 sweep over 232–280 in both modes before calling it a difference.

## PMU verification (later)
`resource_stalls.*` / `rat_stalls` style events (event names vary by generation;
check `perf list`) should show the stall source switching from ROB to register file.
