# Q3 — Does the processor predict branches? (10 pts)

## Idea
Loop over an array and execute one conditional branch per element, driven by the
element's value. Both paths do the same work (one `add`), so the only thing that
differs between patterns is how predictable the branch is.

- Always-taken / never-taken → trivially predictable.
- Short repeating patterns → predictable by a history-based predictor.
- Random (50/50, i.i.d.) → unpredictable.

If random is much slower than the patterned runs that contain the same 50/50 mix of
directions (`alt`, `period:P`), the processor must be speculating on the branch
direction. That means it has branch prediction. A non-predicting pipeline would pay the
same stall on every branch regardless of pattern.

The period sweep (4 … 65536) also shows how long a repeating pattern the predictor
can learn.

## Implementation
| File | What it does |
|---|---|
| `bench/kernel.S` | `branch_kernel(pat, len, passes)`: the branch is written in asm so the compiler can't turn it into a `cmov`. |
| `bench/q3_bench.c` | Builds pattern arrays (1 MiB each), calibrates, trains with one pass, then times `-n` passes. Also used by Q15. |
| `plots/plot.py` | Bar chart of cycles/branch per pattern. |

Code snippet:
```asm
.Lloop: movzbl (%rdi,%rcx), %r8d
        test   %r8d, %r8d
        jnz    .Ltaken          # <-- branch under test
        add    %r10, %r9
        jmp    .Ljoin
.Ltaken: add   %r10, %rax
.Ljoin: inc    %rcx
        cmp    %rsi, %rcx
        jb     .Lloop
```

## How to run
```bash
cd q03_branch/bench
./run.sh native 2
./run.sh sgx 2              # same driver; kernels + data inside an SGX enclave
python3 ../plots/plot.py    # -> plots/q3_branch.png
```
Bench flags: `-p patterns` (comma list: `taken`, `nottaken`, `alt`, `period:P`,
`random`, `bias:F`), `-t trials`, `-n passes` (4), `-l len` (1 MiB), `-r seed`.

CSV columns: `pattern,trial,ticks,cycles,branches,taken_frac,cyc_per_branch`.

## Interpreting results
- Compare `random` against `alt` / `period:16`. These have the same direction mix
  (≈ 50% taken) and differ only in predictability.
- `taken`/`nottaken` are ~1 cycle cheaper than `alt` because there is no alternation
  between the two paths, and so fewer taken jumps on average.
- The period at which cost jumps toward the random level is roughly the predictor's
  history/capacity limit (useful context for Q13; not needed for Q3).

## Baseline (artemisia, native, CPU 2, 11 trials)
| pattern | cycles/branch |
|---|---|
| taken / nottaken | 2.0 |
| alt (1010…) | 3.0 |
| period:16 … period:4096 | 3.2 – 3.6 |
| period:16384 | 12.3 |
| period:65536 | 13.8 |
| random | 14.1 |

Random costs ~11 cycles more per branch than the equally mixed but learnable
patterns → branch prediction. Repeating patterns up to 4096 branches long are learned.

**SGX enclave (same machine, 11 trials):** identical within noise (random 14.16, alt 3.00, period:4096 3.55, period:16384 12.83). In both modes the all-taken / all-not-taken patterns flip between ~2.0 and ~3.2 cycles from trial to trial (more often in SGX: `taken` median 2.30). Cause not yet known; it doesn't change the conclusion.

## PMU verification (later)
`perf stat -e branches,branch-misses ./q3_bench -p alt,random -t 3`: the miss rate
should be ≈ 0% for `alt` and ≈ 50% for `random`.
