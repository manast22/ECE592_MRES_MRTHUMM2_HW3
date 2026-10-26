# ECE 492/592 Homework 3 — Microarchitecture Reverse Engineering Across Machines

**Track B** (individual work, AI use permitted and disclosed).
Due November 3, 2026, 11:59 PM Eastern.

## Selected Questions (115 points; 100 required)

| #  | Question                                   | Points | What changes in the harness                                |
|----|--------------------------------------------|--------|------------------------------------------------------------|
| 1  | Pipelined?                                 | 10     | Dependent vs. independent add chains                       |
| 2  | Out-of-order?                              | 10     | Two independent cache-miss loads, with/without filler      |
| 3  | Branch prediction?                         | 10     | Predictable vs. random branch pattern                      |
| 15 | Pipeline depth                             | 10     | Reuse Q3 data: cycles lost per mispredict                  |
| 14 | Fetch width                                | 10     | NOPs of different byte lengths                             |
| 4  | ROB size                                   | 30     | Q2's experiment, sweeping the amount of filler             |
| 5  | Physical register file size + class        | 35     | Q4's experiment with register-writing filler               |
|    | **Total**                                  | **115**|                                                            |

**Why these:** Q1, Q2, Q3, Q15 are close to textbook experiments. Q4 is a direct extension of Q2, and Q5 is Q4 with different filler, so its 35 points cost little extra work.

**Skipped:** TLB questions (6–9) — SGX enclave memory uses only 4 KB pages (Q9 not feasible) and EPC limits complicate sweeps. BTB questions (10–12) — multi-level BTBs make results noisy. Q13 (predictor type) — hard to conclude with confidence. Q16 (SMT sharing) — needs SMT sibling control inside the enclave.

**Fallback:** if Q5 is messy, do Q8 (TLB miss cost) + Q9 (page sizes) for 20 points, reusing the Q2/Q4 pointer chase and reporting the enclave huge-page limitation.

## Experiment Plan

### Q1 — Pipelined?
Time N dependent adds against N independent adds spread over several registers. If the independent version runs faster than 1/latency instructions per cycle, instructions overlap, so the processor is pipelined.

### Q2 — Out-of-order?
Build a pointer chase over a buffer much larger than the LLC so every load misses. Place two loads from independent chains back to back. If total time is ≈ 1 miss instead of 2, the misses overlapped, so execution is out-of-order. Repeat with and without filler between the loads.

### Q3 — Branch prediction?
Loop containing a branch driven by an array. Compare always-taken, short repeating pattern, and random pattern. Random being much slower than patterned (and `branch-misses` rising, if `perf` works) shows the processor predicts branches.

### Q15 — Pipeline depth
Using Q3 data: `(random time − predictable time) / number of mispredicts` = cycles per mispredict (often ~15–20). This is the front-end-to-resolution refill penalty, a **lower bound** on depth, not an exact stage count.

### Q14 — Fetch width
Long unrolled blocks of NOPs of 1, 4, 8, and 15 bytes. IPC saturates for short NOPs; bytes/cycle saturates for long NOPs. The bytes-per-cycle ceiling (often 16 B/cycle for legacy decode) is the fetch estimate. Caveat: a very large code footprint can fall out of the µop cache.

### Q4 — ROB size
Method from Henry Wong's "Measuring reorder buffer capacity": cache miss, then N independent filler instructions (e.g. NOPs), then a second independent miss. Plot time vs. N; the jump (time roughly doubles) is where the second miss no longer fits in the ROB. That N is the ROB-size estimate.

### Q5 — Physical register file size + class
Same setup as Q4, but the filler writes registers (e.g. `add rax, rbx`). Avoid zeroing idioms (`xor reg,reg`) and plain `mov`s, since rename/move elimination may avoid allocating a physical register. The knee now appears where physical registers run out. Repeat with vector filler (e.g. `vaddps ymm`); different knees for integer and vector filler show separate register classes.

## Measurement Hygiene

- Pin to one core with `taskset`; keep its SMT sibling idle.
- ≥ 10 repetitions per data point; report median and min/max (or std. dev.).
- `rdtsc` ticks at a fixed frequency, not core cycles. Calibrate with a long dependent 1-cycle add chain (1 add/cycle) to get the TSC-to-cycle ratio. This also covers the case where `perf` is blocked (`perf_event_paranoid`).
- Use `asm volatile` or `.S` files so the compiler cannot optimize filler away; these become the report's code snippets.

### PMU policy

- **Initial measurements do not use the PMU.** All conclusions are drawn from `rdtsc` timing alone (calibrated as above), so the method also works inside an enclave and on machines where `perf` is blocked.
- **PMU counters are used afterwards, only as verification.** Once a result is derived from timing, check it against counters (e.g. `branch-misses` for Q3/Q15, `cycles`/`instructions` for IPC in Q1/Q14, the resource-stall events for Q4/Q5) where `perf` is permitted. Report agreement or disagreement separately from the timing-derived findings, and note machines where counters are unavailable.

## Enclave Plan (main risk — start early)

- **Implemented with the Intel SGX SDK** (2.23, hardware **debug** enclave, SGX1-style static heap with no EDMM), not Gramine. Each experiment's timed part (kernels, timing, test data) runs inside the enclave, and the host does setup and output. See `common/sgx/README.md`.
- `rdtsc` turned out to work natively inside the enclave on Artemisia (`common/sgx/timer_probe`), so timing is done in-enclave and the ~16k-cycle ECALL cost is never part of a measurement. Perf counters are generally hidden from enclaves, which is consistent with the PMU-only-for-verification policy.
- Q2/Q4/Q5 buffer must exceed the LLC yet fit in usable EPC. Encrypted-memory misses cost more, so absolute times should grow while the knee position in N stays the same — a point to discuss.
- If a machine lacks SGX, document it and still run the ordinary experiments on two machines.

## Machines

Two course machines with different microarchitectures (e.g. Skylake vs. Ice Lake); at least one SGX-capable. Record `lscpu` and `/proc/cpuinfo` for each, plus the microarchitecture and any unsupported features or access limitations.

| Machine | CPU model | Microarchitecture | SGX? | Notes |
|---------|-----------|-------------------|------|-------|
| Artemisia | Intel Xeon Gold 5420+ | Sapphire Rapids (Golden Cove cores; `lscpu` family 6, model 143, stepping 8) | **Yes (as of Oct 26 re-check)** — `sgx`, `sgx_lc` flags; `/dev/sgx_enclave`, `/dev/sgx_provision`, `/dev/sgx_vepc` present; two EPC sections in `dmesg` | See below |
| B       | TBD       | TBD               | TBD  |       |

### Artemisia details

- 2 sockets × 28 cores × 2 threads = 112 logical CPUs; 2 NUMA nodes.
  - Node 0: CPUs 0–27, 56–83. Node 1: CPUs 28–55, 84–111.
  - Assumed SMT siblings are CPU *n* and *n*+56 (verify via `/sys/devices/system/cpu/cpu*/topology/thread_siblings_list`); pin to one and keep the sibling idle.
- Min 800 MHz; max reported as 2000 MHz in the first `lscpu` capture and 4100 MHz in the second (turbo ceiling vs. nominal, or a re-check; re-capture and record which). Frequency scaling is on, so calibrate TSC-to-cycle per run. `constant_tsc`, `nonstop_tsc`, `tsc_known_freq`, `rdtscp` and `art` are present, so `rdtsc` is usable natively.
- Kernel 6.17.8 (el9.elrepo), GCC 11.5.0, Python 3.9.25.
- **SGX status:** originally the kernel log said `x86/cpu: SGX disabled or unsupported by BIOS.` After the BIOS change, `lscpu` shows `sgx` and `sgx_lc` (flexible launch control) and `dmesg` shows two EPC sections (`0x4040600000-0x407f3fefff` and `0x8040600000-0x807fffffff`, i.e. roughly 1 GiB each for the two sockets; compute exact total from the ranges and record it).
- **Device access (resolved Oct 26):** `mrthumm2` was added to the `sgx` group (`/dev/sgx_enclave` is `root:sgx` 0660). A new login session is needed for it to take effect. A hardware debug enclave from the Intel SGX SDK (`/opt/intel/sgxsdk` 2.23) builds, signs and runs.
- **Timers in the enclave (verified Oct 26):** `rdtsc`/`rdtscp` run natively inside the enclave, with the same resolution as native, and the TSC->cycle calibration agrees within 0.6%. An ECALL costs ~16k cycles. See `common/sgx/timer_probe/README.md`.
- **Gramine tooling (not used):** the Gramine Python package `graminelibos` is not installed, and the system Python 3.9 also lacks `click`, `tomli`, `tomli_w` and `voluptuous`. As a result `gramine-manifest`, `gramine-sgx-sign` and `gramine-sgx-gen-private-key` all fail, so Gramine cannot build manifests. The enclave runs use the Intel SGX SDK instead, so this no longer blocks anything.
- Artemisia is now the SGX-capable machine, so it supplies the native-vs-enclave comparison; the second machine only needs to differ in microarchitecture.
- Full `lscpu` and `/proc/cpuinfo` output is saved automatically in `machines/artemisia.txt` on the first benchmark run.

## Repository Layout

```
common/                  shared harness
  bench.h, bench.c       rdtsc helpers, TSC->cycle calibration, stats
  calib.S                calibration kernels (dependent add / imul chains)
  common.mk              shared make rules: native binary + `make sgx`
  kt.h                   kernel-side interface (timed part, compiled native AND into the enclave)
  kbackend.h, kb_native.c  host-side backend for native runs
  sgx/                   SGX backend: kb.edl, enclave_main.c, kb_sgx.c, sgx.mk, timer_probe/
  run_lib.sh             run_bench: taskset pinning, SMT-sibling check, output capture
  sysinfo.sh             records machines/<host>.txt
  chase/                 pointer-chase generator + driver shared by Q2/Q4/Q5
  plotlib.py, knee.py    plot helpers
q01_pipelined/           Q1   (each experiment: README.md, bench/, results/, plots/)
q02_ooo/                 Q2
q03_branch/              Q3
q04_rob/                 Q4
q05_prf/                 Q5
q14_fetch_width/         Q14
q15_pipeline_depth/      Q15  (builds from q03 sources)
machines/                per-host lscpu / cpuinfo / SGX snapshot
report/                  PDF report (later)
AI_LOG.md                AI-use disclosure log (later)
```

Each experiment folder has its own README with implementation details, commands, run
flow, CSV format, how to interpret results, and the current baseline numbers.

## Reproduction

Requirements: gcc, make, python3 with numpy + matplotlib. For enclave runs: the Intel SGX SDK in `/opt/intel/sgxsdk`, `openssl`, and a login session in the `sgx` group.

```bash
cd qNN_<name>/bench
./run.sh native 2        # MODE = native | sgx ; 2nd arg = CPU to pin to
python3 ../plots/plot.py
```

- `run.sh` builds the benchmark, pins it with `taskset`, reports how busy the SMT
  sibling is (on artemisia the siblings are n / n+56, so CPU 2 pairs with 58), and writes
  `results/<host>_<mode>.csv`. Plot scripts plot every CSV in `results/` side by side,
  so runs from both machines, and native vs. SGX, overlay automatically.
- `sgx` mode builds `<bin>_sgx` and the signed `<bin>_sgx.enclave.so` (`make sgx`) and
  runs the same driver with the kernels and their data inside the enclave. The enclave heap
  is `ENCLAVE_HEAP` in each bench Makefile (288 MiB for the pointer chases). The signing key
  is created on first build at `~/.config/sgx/enclave_private.pem`.
- Every CSV starts with `#` metadata: host, mode, CPU, sibling load, command,
  calibration (`cyc_per_tick`, imul sanity check), and end-of-run clock drift.

Run everything on one machine:
```bash
for q in q01_pipelined q02_ooo q03_branch q04_rob q05_prf q14_fetch_width q15_pipeline_depth; do
    $q/bench/run.sh native 2 && $q/bench/run.sh sgx 2 && python3 $q/plots/plot.py
done
```

## Baseline Status (artemisia, native vs SGX enclave, CPU 2, 11 trials, Oct 26)

| Q | Native | SGX enclave |
|---|---|---|
| 1 | Independent add IPC 4.73 vs dependent 1.00; imul 1.00 vs 0.333 → pipelined | identical (4.72; 1.00 vs 0.333) |
| 2 | 1 miss 361 cyc; 2 dependent 2.00×; 2 indep 1.01×; with consumer 1.04× → out-of-order | 1 miss **415 cyc (+15%)**; 1.94× / 1.04× / 1.08×, same conclusion |
| 3 | Random 14.1 cyc/branch vs 3.0–3.6 learnable; periods ≤ 4096 learned | identical |
| 4 | Knee N = 496 → 504 → ROB ≈ 500–506 (published 512) | same knee, higher plateaus |
| 5 | Knees: int 208–216, ymm 240–248, mix 424–432 → separate int / vector PRFs | int and mix identical; ymm 256–264 (the native transition is ragged over 240–272, so not yet a clear difference) |
| 14 | ≈ 6 instr/cycle; legacy fetch ≥ 29 B/cycle; L2-fed 12.8 B/cycle | identical |
| 15 | ≈ 22 cyc per mispredict at F = 0.5; varies with F → needs `branch-misses` check | identical (22.2) |

Observed so far: the enclave changes **memory** cost (encrypted EPC, +15% per miss) but not
core structures (pipeline, ROB, register files, predictor, front end), as expected. In both
modes the all-taken / all-not-taken branch patterns flip between ~2.0 and ~3.2 cycles from
trial to trial, more often in SGX. This doesn't affect the Q3 / Q15 conclusions.

Not yet done: second machine, PMU verification, step-1 sweeps near the Q4 / Q5 knees.

## AI Use Disclosure

AI (Claude Code) was used for planning and README drafting; see `AI_LOG.md` for the full log.

## Deliverable

ZIP containing: PDF report, source code, raw data, plotting scripts, reproduction instructions, and AI-use log.
