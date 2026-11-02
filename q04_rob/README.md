# Q4 — Reorder buffer size (30 pts)

## Idea
This is Henry Wong's method ("Measuring Reorder Buffer Capacity", 2013), extending Q2:
```
loop:  load A (miss) ; N × nop ; load B (independent miss) ; N × nop
```
While load A waits for DRAM it sits at the head of the ROB and blocks retirement. Load B
can start only if it has already been allocated into the ROB, which requires N + 2 ≲ ROB
size. Below that, the two misses overlap (~1 miss/iteration). Above it, B waits for A to
retire (~2 misses/iteration). The N at the jump is the ROB size.

NOPs are used because they occupy a ROB entry but write no register and need no
scheduler or load/store entry. So the ROB is the first structure to fill up.

## Implementation
The same harness as Q2 (`common/chase/`), generated with `--kinds nop --n 0:800:8`, which
gives 101 kernels, one per N.

| File | What it does |
|---|---|
| `bench/Makefile` | Generates `kernels.S` (sweep N = 0..800 step 8), links `q4_bench`. |
| `plots/plot.py` | Curve of median cycles/iteration vs N, with a min–max band. Reports the largest single-step jump as the knee. |
| `common/knee.py` | Knee detection (argmax of the step-to-step rise in the median). |

Code snippet (N = 2 shown):
```asm
1:  mov (%rax), %rax    # miss A
    nop
    nop
    mov (%rcx), %rcx    # miss B (independent chain)
    nop
    nop
    dec %rdx
    jnz 1b
```

## How to run
```bash
cd q04_rob/bench
./run.sh native 2           # ~10 s
./run.sh sgx 2              # same driver; kernels + data inside an SGX enclave
python3 ../plots/plot.py    # -> plots/compare/q4_rob.png (or `plot.py <machine>` -> plots/<machine>/) + knee on stdout
```
`run.sh` runs the coarse grid (`-n 0:800:8`). For the step-1 sweep around the knee (N = 470..530,
21 trials) run `./zoom.sh native 2` / `./zoom.sh sgx 2` (writes `results/<machine>/zoom/<mode>.csv`)
and `python3 ../plots/plot_zoom.py`. Both grids are built into the same binary (`GEN_ARGS`);
the driver option `-n lo:hi:step` picks which kernels run.

## Interpreting results
- Flat region at ~1 miss/iteration, then a step to ~2 misses/iteration.
- ROB ≈ N at the step + 2 (the two loads). The fused `dec/jnz` uses one more entry,
  but it sits *after* B, so it doesn't count against the window between A and B.
- The slow upward slope on both plateaus is the cost of fetching and retiring the
  filler itself. It is not a capacity effect.
- Native vs SGX: the step position should not move. Only the plateau heights change,
  because enclave misses are slower.

## Baseline (artemisia, native, CPU 2, 11 trials)
Coarse sweep (step 8): jump between **N = 496 and N = 504** (+194 cycles).

**Step-1 zoom (Nov 1, N = 470–530, 21 trials, `zoom.sh`):**
```
N        488  492  493  494  495  496  497  498  500  504
native   477  477  488  523  548  573  617  764  765  766   cycles/iter (median)
sgx      557  558  575  618  659  690  741  923  927  925
```
- Overlap holds up to N ≈ 492. A short partial ramp runs over 493–497, and the second
  miss is fully serialized from **N = 498**, in both modes.
- The per-trial halfway crossing is at N = 497–498 in 18 of 21 native trials and all 21 SGX trials.
- → **ROB ≈ 500 entries** (N + 2 loads) measured, vs 512 published (−2.3%).
- The 493–497 ramp is a phase effect: the previous iteration's load B can still be at the ROB
  head for a few cycles when load A issues, so the usable window is slightly smaller in some
  iterations. This, and possibly entries kept back by the core, would explain the gap to 512.
  Report it as measured ≈ 500, consistent with 512.

**SGX enclave (same machine, 11 trials):** same jump, N = 496 → 504 (+223 cycles). Plateaus are higher because enclave misses cost more: 436 cycles at N = 0 and 890 at N = 504, vs 374 and 766 natively. The ROB estimate is unchanged.

## PMU verification (later)
`perf stat -e resource_stalls.rob` (or `cycle_activity.stalls_total`) should rise
sharply past the knee.
