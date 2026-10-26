# Q2 — Does the processor execute out of order? (10 pts)

## Idea
Two pointer chases over buffers much larger than the LLC, so every load is a DRAM miss.
- One load per iteration → 1 miss latency per iteration (baseline).
- Two loads on the **same** chain → 2 misses, necessarily serial.
- Two loads on **independent** chains → about 1 miss if the second load can start
  while the first is still outstanding.

The key variant is **`use`**: load A, then 4 instructions that *consume* A's result,
then load B. An in-order core stalls at the first consumer until A returns, so B would
start only after A finishes (2 misses). Only an out-of-order core can issue B past the
stalled consumers. That makes `use` ≈ 1 miss the strongest evidence. Plain back-to-back
loads alone could also overlap on an in-order core with a non-blocking cache.

The NOP-filler variants (64/128/192 NOPs between the loads) show the overlap survives
a large window of younger instructions. Q4 sweeps that filler until it breaks.

## Implementation
Shared with Q4/Q5 in `common/chase/`:

| File | What it does |
|---|---|
| `common/chase/gen_chase.py` | Generates the asm kernels (`load A; filler×N; load B; filler×N` loop) plus a table of all kernels. Q2 uses `--extra --kinds nop --n 0:192:64`. |
| `common/chase/chase_main.c` | Builds two random single-cycle pointer chains (Sattolo shuffle, one node per 64 B line, 128 MiB each by default), calibrates, times every kernel. |
| `bench/Makefile` | Generates `kernels.S` and links `q2_bench`. |
| `plots/plot.py` | Bar chart of cycles/iteration; table expressed in "number of misses". |

Code snippet (`use` kernel loop body):
```asm
1:  mov (%rax), %rax        # load A (chain p) — misses
    lea 1(%rax), %r8        # consumers of A: an in-order core stalls here
    add %r8, %r9
    add %r9, %r10
    add %r10, %r11
    mov (%rcx), %rcx        # load B (chain q) — independent miss
    dec %rdx
    jnz 1b
```

## How to run
```bash
cd q02_ooo/bench
./run.sh native 2
./run.sh sgx 2              # same driver; kernels + data inside an SGX enclave
python3 ../plots/plot.py   # -> plots/q2_overlap.png
```
Bench flags: `-t trials` (11), `-i iters` per measurement (20000), `-s MB` per chain
(128; must exceed the LLC and, in SGX, fit in the enclave), `-k kinds` filter,
`-H` transparent huge pages (native only), `-r seed`.

CSV columns: `kind,n,trial,ticks,cycles,iters,cyc_per_iter`.

## Interpreting results
Normalise by `single`. `serial` ≈ 2.0 confirms the miss latency. `nop,0` and `use` ≈ 1.0 →
the second miss overlapped the first → out-of-order execution.

## Baseline (artemisia, native, CPU 2, 11 trials)
| variant | cycles/iter | misses |
|---|---|---|
| 1 miss | 368 | 1.00 |
| 2 dependent | 734 | 2.00 |
| 2 indep + use | 382 | 1.04 |
| 2 indep | 373 | 1.01 |
| 2 indep, 192 NOPs | 383 | 1.04 |

**SGX enclave (same machine, 11 trials):** 1 miss = 415 cycles (+15% vs native, from encrypted EPC memory); 2 dependent 1.94×, 2 indep 1.04×, with consumer 1.08×. Same conclusion.

## Enclave notes
Buffers use 4 KB pages (default; `-H` off) so native and SGX runs are comparable. Expect
a larger absolute miss cost in SGX (memory encryption), but the same *ratios*.
In SGX mode the chains are built in the enclave heap (`ENCLAVE_HEAP` = 288 MiB in `bench/Makefile`), i.e. in encrypted EPC memory.
