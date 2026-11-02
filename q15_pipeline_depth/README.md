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
The difficulty is knowing *mispredicts* without performance counters. The method below
uses the one case where it is known exactly.

## Method (timing only)
**Anchor: a fair coin.** For i.i.d. 50/50 outcomes (`bias:0.50`), *every* predictor
mispredicts exactly half the time in expectation. The outcome is independent of everything
the predictor can observe, so no history, table or algorithm helps or hurts. With `alt` as
the baseline, the penalty is exact:
```
P = (t(bias:0.50) − t_alt) / 0.5
```
`alt` (1010…) has the same 50/50 path mix and is perfectly predicted. On artemisia it sits
on the same minimum cost as `period:4/16`; on crux it costs more (5.04 vs. 4.41). `period:16`
is printed as an alternative baseline to show the result's sensitivity to the choice.

**Biased coins (F < 0.5) only bound the miss rate from below.** The best possible predictor
mispredicts min(F, 1−F), and a real one can only do worse. So
`(t(F) − base(F)) / min(F, 1−F)` is an **upper bound** on P, tightest at F = 0.5.
Given P, the timing *implies* the actual miss rate at each F:
```
base(F) = t_one + 2·F·(t_alt − t_one)      # perfectly predicted cost at path mix F
miss(F) = (t(F) − base(F)) / P             # t_one = lower median of taken / nottaken
```

**History:** the first analysis divided by min(F, 1−F) as if it were the miss rate, so
the "penalty" drifted from 43 to 22 cycles. Those values are really upper bounds. The PMU
check below confirmed that the predictor mispredicts more than min(F, 1−F), and that the
F = 0.5 point is right.

## Implementation
This reuses the Q3 kernel and driver. `bench/Makefile` builds `q15_bench` from
`q03_branch/bench/` sources; only the pattern list differs. `run.sh` measures the
predictable baselines (`taken`, `nottaken`, `alt`, `period:16`) and i.i.d. patterns with taken
probability F = 0.00 … 0.50 (`bias:F`). `plots/plot.py` implements the method above from
timing results only. PMU validation is separate: `plots/plot_pmu.py` and `report/pmu_tables.md`.

## How to run
```bash
cd q15_pipeline_depth/bench
./run.sh native 2
./run.sh sgx 2              # same driver; kernels + data inside an SGX enclave
./pmu.sh 2                  # optional, native only: PMU check (perf stat)
python3 ../plots/plot.py    # -> plots/compare/q15_penalty.png + table
python3 ../plots/plot_pmu.py   # -> plots/compare/q15_pmu.png (needs pmu.sh output)
```

## Results (artemisia, CPU 2, 11 trials)
| | penalty P (`alt` baseline) | `period:16` baseline |
|---|---|---|
| native | **22.3 cycles** | 22.5 |
| SGX | **22.2 cycles** | 22.6 |

Miss rate implied by timing vs measured by the PMU (native counters; none in the enclave):

| F | best possible | implied, native | implied, SGX | PMU (native) |
|---|---|---|---|---|
| 0.05 | 0.050 | 0.096 | 0.084 | 0.089 |
| 0.10 | 0.100 | 0.175 | 0.165 | 0.169 |
| 0.25 | 0.250 | 0.339 | 0.333 | 0.339 |
| 0.40 | 0.400 | 0.456 | 0.454 | 0.461 |
| 0.50 | 0.500 | 0.500 | 0.500 | 0.500 |

- **Penalty ≈ 22–23 cycles per mispredict**, the same native and in the enclave. It is a lower
  bound on fetch→execute depth: it measures the refill from the front end to branch
  resolution, minus any overlap. For context, published Golden Cove figures are ~17 cycles
  minimum, more when the refill misses the µop cache.
- Timing alone reproduces the PMU miss rates: within 0.013 natively (largest gap at F = 0.15, 0.237 vs 0.224) and within 0.007 in SGX. Natively that is an
  independent check of the method. In the enclave, where counters are hidden, it shows the
  predictor behaves the same (SGX implied rates match native).
- The predictor mispredicts well above the best possible rate on biased noise: ~1.7–1.9× F
  at small F. It presumably keeps learning spurious patterns from the random history.
- The SGX low-F implied rates are slightly below native because SGX's `taken`/`nottaken`
  medians sit in their slow mode (2.30 vs 2.00; the bimodal pattern noted in Q3), which
  raises base(F). This doesn't affect P.

## PMU verification (done Nov 1, native): penalty ≈ 23 cycles, flat across F
`bench/pmu.sh` counts `branches:u`, `branch-misses:u`, `cycles:u`, `instructions:u` for each
pattern. It runs the bench with 8 and with 4 timed passes and subtracts, so everything except
exactly 3 × 4 × 1 MiB = 12.6 M data branches cancels. `plots/plot_pmu.py` →
`plots/compare/q15_pmu.png`.

| F | assumed miss rate | **measured** miss rate | penalty, assumed rate | **penalty, measured rate** |
|---|---|---|---|---|
| 0.05 | 0.050 | 0.089 | 41.6 | **23.4** |
| 0.10 | 0.100 | 0.169 | 37.9 | **22.4** |
| 0.25 | 0.250 | 0.339 | 30.8 | **22.7** |
| 0.40 | 0.400 | 0.461 | 26.6 | **23.1** |
| 0.50 | 0.500 | 0.500 | 22.6 | **22.6** |
| random | | 0.4997 | | **23.2** |

- **The drift was the model, not the machine.** On biased noise the predictor mispredicts
  much more than the minority fraction: ~1.7× F at small F. It presumably keeps finding
  spurious patterns in the global history and following them. With the measured miss rate
  the penalty is **flat: 22.4–23.6 cycles, median 22.8**.
- Result: **≈ 23 cycles lost per mispredict.** This is a lower bound on the fetch→execute
  depth: it measures the refill from the front end to branch resolution, minus any overlap.
  For context, published Golden Cove figures are ~17 cycles minimum, more when the refill
  misses the µop cache.
- Here PMU cycles per branch come from the same counters, so the timing and miss counts are
  self-consistent. They agree with the TSC timing within a few percent for most patterns
  (`random` 14.28 vs 14.14; `nottaken` 2.05 vs 2.00). `alt` reads 2.66 (PMU, steady state)
  vs 3.00 (TSC); this changes the baseline by < 0.4 cycles and the penalty by < 1 cycle.
- Counters are not visible inside the enclave, so this check is native only. The SGX timing
  (22.2 cycles at F = 0.5) matches native, so the same miss rates apply.

## Crux (i7-9700, native, 11 trials)
Timing result: **19.4 cycles** (`alt` baseline), 20.6 (`period:16`).

PMU validation (`report/pmu_tables.md`): the method's assumptions hold, with `random` missing
at 0.4999 and `alt` at 0.00001. So crux's dearer `alt` is not mispredicts, and the baseline is
the only uncertainty. PMU estimates span 18.5–21.6 cycles, the top being the slope of cycles
against measured miss rate. Timing-implied miss rates are within 0.022 of the PMU.

`plot_pmu.py`'s per-F values fall as low as 10.7 at small F. Its base(F) rises toward `alt`, which
is too high here, so don't quote those; artemisia's flat 22–24 doesn't show this because its
`alt` is cheaper. On the same PMU estimates artemisia spans 22.5–24.7, so crux is shorter.
