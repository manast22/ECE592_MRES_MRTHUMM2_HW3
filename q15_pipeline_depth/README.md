# Q15 — Pipeline depth (10 pts)

## Idea
A mispredicted branch throws away everything fetched after it. Fetch then restarts on
the correct path, and the front end has to refill before useful work resumes. The time
lost per mispredict is the **front-end-to-branch-resolution refill penalty**. It is a
lower bound on pipeline depth (fetch → execute), not an exact stage count: it doesn't
include the stages after execute (retire), and overlap with other work can hide part of it.

Estimate it as
```
penalty = (t_unpredictable − t_predictable) / mispredicts
```

## Implementation
This reuses the Q3 kernel and driver. `bench/Makefile` builds `q15_bench` from
`q03_branch/bench/` sources; only the pattern list differs.

`run.sh` measures:
- predictable baselines: `taken`, `nottaken`, `alt`, `period:16`;
- i.i.d. patterns with taken probability **F = 0.00 … 0.50** (`bias:F`). A predictor that
  guesses the majority direction mispredicts ≈ min(F, 1−F) of the time.

`plots/plot.py` computes, for every F:
```
base(F)    = t_nottaken + 2·F·(t_alt − t_nottaken)   # perfectly predicted cost at this path mix
penalty(F) = (t(F) − base(F)) / F
```
The F = 0.5 point is the textbook "(random − predictable) / mispredicts".

## How to run
```bash
cd q15_pipeline_depth/bench
./run.sh native 2
./run.sh sgx 2              # same driver; kernels + data inside an SGX enclave
python3 ../plots/plot.py   # -> plots/q15_penalty.png + penalty table
```

## Interpreting results
- Left panel: cost per branch rises with F. Right panel: implied cycles per mispredict.
- If the penalty is constant across F, the model fits. If it varies, the assumption
  "mispredicts = min(F, 1−F)" is off (the predictor does worse than majority-vote on
  noise) and/or mispredicts overlap with each other.
  **This needs PMU verification:** take the measured `branch-misses` per F and recompute.

## Baseline (artemisia, native, CPU 2, 11 trials)
| F | cycles/branch | implied penalty |
|---|---|---|
| 0.05 | 4.24 | 41.7 |
| 0.25 | 10.07 | 30.0 |
| 0.50 (random) | 14.20 | **22.3** |

At F = 0.5: ~22 cycles per mispredict, consistent with published figures for Golden
Cove (~17+ cycles minimum, higher on a µop-cache miss). The penalty implied at low F is
too high. Most likely the predictor mispredicts *more* than F on biased noise (it
sometimes follows spurious history), so "mispredicts = F" undercounts. Resolve this with
`perf stat -e branch-misses` before quoting a final number.

**SGX enclave (same machine, 11 trials):** 22.2 cycles per mispredict at F = 0.5 (native 22.3). Same F-dependence (37 → 22).

## PMU verification (later)
```bash
for f in 0.05 0.25 0.5; do perf stat -e branches,branch-misses ./q15_bench -p bias:$f -t 3; done
```
Replace min(F, 1−F) with the measured miss rate and check that the penalty becomes flat.
