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
- **PMU counters are used afterwards, only as verification.** Once a result is derived from timing, check it against counters (e.g. `branch-misses` for Q3/Q15, `cycles`/`instructions` for IPC in Q1/Q14, the resource-stall events for Q4/Q5) where `perf` is permitted. Report agreement or disagreement separately from the timing-derived findings, and note machines where counters are unavailable. Timing plots read no PMU data; `common/pmu_verify.sh` runs after them and writes the comparison tables to `report/pmu_tables.md`.

## Enclave Plan (main risk — start early)

- **Implemented with the Intel SGX SDK** (2.23 on Artemisia, 2.30 on Crux, hardware **debug** enclave, SGX1-style static heap with no EDMM), not Gramine. Each experiment's timed part (kernels, timing, test data) runs inside the enclave, and the host does setup and output. See `common/sgx/README.md`.
- `rdtsc` turned out to work natively inside the enclave on Artemisia (`common/sgx/timer_probe`), so timing is done in-enclave and the ~16k-cycle ECALL cost is never part of a measurement. On Crux (SGX1) `rdtsc` faults in an enclave, so the enclave reads a TSC value that a host thread publishes (`common/sgx/README.md`). Perf counters are generally hidden from enclaves, which is consistent with the PMU-only-for-verification policy.
- Q2/Q4/Q5 buffer must exceed the LLC yet fit in usable EPC. Encrypted-memory misses cost more, so absolute times should grow while the knee position in N stays the same — a point to discuss.
- If a machine lacks SGX, document it and still run the ordinary experiments on two machines.

## Machines

Two course machines with different microarchitectures (e.g. Skylake vs. Ice Lake); at least one SGX-capable. Record `lscpu` and `/proc/cpuinfo` for each, plus the microarchitecture and any unsupported features or access limitations.

| Machine | CPU model | Microarchitecture | SGX? | Notes |
|---------|-----------|-------------------|------|-------|
| Artemisia | Intel Xeon Gold 5420+ | Sapphire Rapids (Golden Cove cores; `lscpu` family 6, model 143, stepping 8) | **Yes (as of Oct 26 re-check)** — `sgx`, `sgx_lc` flags; `/dev/sgx_enclave`, `/dev/sgx_provision`, `/dev/sgx_vepc` present; two EPC sections in `dmesg` | See below |
| Crux | Intel Core i7-9700 | Coffee Lake Refresh (`lscpu` family 6, model 158, stepping 13) | **Yes (enabled Nov 2), SGX1 only** — `sgx`, `sgx_lc` flags; `/dev/sgx_enclave`; CPUID leaf 0x12 reports SGX2 = 0 and a 93 MiB EPC | See below |

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

### Crux details

- Dell OptiPlex 5070, 1 socket × 8 cores, **no SMT**. 12 MiB L3. Max 4700 MHz; the clock measured ~4.68 GHz, dropping to ~4.48 GHz at times (consistent with turbo bins as other cores wake).
- Ubuntu 24.04.5, GCC 13.3.0, Python 3.12.3. **Kernel 6.8.0-88 for native runs, 6.8.0-147 for SGX runs** (updated by the reboot after SGX was enabled; native not rerun). No AVX-512, so the Q5 `ymm_state` test does not apply.
- **SGX:** SGX1 only, 93 MiB EPC, flexible launch control. Intel SGX SDK 2.30 in `~/sgx-2.30/sgxsdk`, with the real uRTS from the PSW packages unpacked to `~/sgx-2.30/psw` (no system install; the SDK's own `libsgx_urts.so` is only a stub). Enclave runs use `common/run_sgx1.sh`.
- **PMU:** `perf_event_paranoid` defaults to 4, which blocks counting. It was set to 2 with sudo for the validation run only.
- Full details are in `machines/crux.txt` (native runs) and `machines/crux_sgx.txt` (SGX runs).

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
  sysinfo.sh             records machines/<machine>.txt
  chase/                 pointer-chase generator + driver shared by Q2/Q4/Q5
  plotlib.py, knee.py    plot helpers
  pmu_verify.sh          perf-counter cross-check of the timing results (native only)
  pmu_tables.py          timing vs. PMU tables -> report/pmu_tables.md
  run_sgx1.sh            SGX runs on a small-EPC SGX1 machine (smaller chains)
q01_pipelined/           Q1   (each experiment: README.md, bench/, results/<machine>/, plots/)
q02_ooo/                 Q2
q03_branch/              Q3
q04_rob/                 Q4
q05_prf/                 Q5
q14_fetch_width/         Q14
q15_pipeline_depth/      Q15  (builds from q03 sources)
machines/                per-host lscpu / cpuinfo / SGX snapshot
report/                  report outline (PDF report to come)
AI_LOG.md                AI-use disclosure log (keep updated)
```

Each experiment folder has its own README with implementation details, commands, run
flow, CSV format, how to interpret results, and the current baseline numbers.

## Reproduction

Requirements: gcc, make, python3 with numpy + matplotlib. For enclave runs: the Intel SGX SDK in `/opt/intel/sgxsdk` (or set `SGX_SDK`), `openssl`, and a login session in the `sgx` group.

```bash
cd qNN_<name>/bench
./run.sh native 2        # MODE = native | sgx ; 2nd arg = CPU to pin to
python3 ../plots/plot.py
```

- `run.sh` builds the benchmark, pins it with `taskset`, reports how busy the SMT
  sibling is (on artemisia the siblings are n / n+56, so CPU 2 pairs with 58), and writes
  `results/<machine>/<mode>.csv`, where `<machine>` is the short hostname (override with
  `MACHINE=name ./run.sh ...`). So running on artemisia fills `results/artemisia/`, and on
  the second machine its own folder is created automatically. Plot scripts plot every CSV
  under `results/*/` side by side, so both machines, and native vs. SGX, overlay automatically.
  Figures go to `plots/compare/` (all machines overlaid, `plot.py`) or `plots/<machine>/`
  (that machine only, `plot.py <machine>`); `common/plot_all.sh [machine]` regenerates all of them.
- `sgx` mode builds `<bin>_sgx` and the signed `<bin>_sgx.enclave.so` (`make sgx`) and
  runs the same driver with the kernels and their data inside the enclave. The enclave heap
  is `ENCLAVE_HEAP` in each bench Makefile (288 MiB for the pointer chases). The signing key
  is created on first build at `~/.config/sgx/enclave_private.pem`.
- Every CSV starts with `#` metadata: host, mode, CPU, sibling load, command,
  calibration (`cyc_per_tick`, imul sanity check), and end-of-run clock drift.

Run everything on one machine:
```bash
for q in q01_pipelined q02_ooo q03_branch q04_rob q05_prf q14_fetch_width q15_pipeline_depth; do
    $q/bench/run.sh native 2 && $q/bench/run.sh sgx 2 && python3 $q/plots/plot.py            # -> plots/compare/
    python3 $q/plots/plot.py "$(hostname -s)"   # -> plots/<machine>/
done
```

## Running on Another Machine

```bash
git clone <repo> && cd ECE592_MRES_MRTHUMM2_HW3
common/preflight.sh 2        # tools, CPU features, the pin CPU, LLC vs buffer size, SGX, perf
common/run_all.sh 2          # everything, ~10 min per mode; adds sgx if /dev/sgx_enclave is usable
```
- Results go to `q*/results/<hostname>/` (set `MACHINE=name` to override), and machine info
  to `machines/<hostname>.txt`. Plots in `q*/plots/compare/` overlay all machines;
  `common/plot_all.sh <machine>` writes one machine's figures to `q*/plots/<machine>/`.
- Pick a CPU that `taskset -cp $$` allows and whose SMT sibling is idle.
- Machine-specific parts adapt automatically:
  - Q4/Q5 step-1 zoom windows come from that machine's own coarse sweep. Override with
    `ZOOM=lo:hi[,lo:hi] ./zoom.sh ...`.
  - Q5 controls needing BMI1/BMI2/AVX-512VL are built only where the CPU has them.
  - `ymm_state.sh` skips on non-AVX-512 CPUs.
  - PMU checks run only where `perf` counting works.
- If preflight warns that the LLC is not much smaller than a 128 MiB chain (some AMD EPYC
  parts), pass a larger `-s` to the Q2/Q4/Q5 runs (and raise `ENCLAVE_HEAP` for SGX).

## Results Status (artemisia, native vs SGX enclave, CPU 2; updated Nov 1)

Coarse sweeps: 11 trials (Oct 26, Q5 re-run Nov 1). Q4/Q5 step-1 zooms: 21 trials (Nov 1).
PMU checks: native only (Nov 1).

| Q | Native | SGX enclave | PMU check |
|---|---|---|---|
| 1 | Independent add IPC 4.73 vs dependent 1.00; imul 1.00 vs 0.333 → pipelined | identical | ✓ IPC 1.001 / 4.72 / 0.331 / 1.023; also validates the TSC→cycle calibration |
| 2 | 1 miss 361 cyc; 2 dependent 2.00×; 2 indep 1.01×; with consumer 1.04× → out-of-order | 1 miss **415 cyc (+15%)**; 1.94× / 1.04× / 1.08× | – |
| 3 | Random 14.1 cyc/branch vs 3.0–3.6 learnable; periods ≤ 4096 learned | identical | ✓ miss rate 0.0000 (alt, period:16, taken) vs 0.4997 (random) |
| 4 | Step-1: full serialization from **N = 498** (ramp 493–497) → **ROB ≈ 500** (published 512) | identical knee (N = 498), higher plateaus | – |
| 5 | Free int regs **≈ 210** (add/andn/shlx/lea r,r all 207–215: flags irrelevant); `lea reg+imm` allocates no register; mix ≈ 2× int → separate int / vector files; free vector **≈ 244** | int / mix identical; vector **≈ 262**. Writing ymm16–31 first gives 244 in SGX too; `xgetbv(1)` shows ymm16–31 in use natively (from glibc) and not in the enclave | – |
| 14 | ≈ 6 instr/cycle; legacy fetch ≥ 29 B/cycle; L2-fed 12.8 B/cycle | identical | – |
| 15 | **22.3 cyc per mispredict**, timing only: (t_random − t_alt) / 0.5, exact because a fair coin is mispredicted 50% by any predictor | **22.2** | ✓ 22.4–23.6 using measured miss rates; timing-implied miss rates match the PMU within 0.013 |

Observed: the enclave changes **memory** cost (encrypted EPC, +15% per miss) but not core
structures. The one structural-looking difference (Q5 vector) is architectural *state*, shown
by `q05_prf/bench/ymm_state.sh`. In both modes the all-taken / all-not-taken branch patterns
flip between ~2.0 and ~3.2 cycles per trial (a front-end effect: two taken branches per
iteration); this doesn't affect any conclusion. Occasional whole-trial slowdowns (~2×) come
from other users' load on Artemisia; they show only in the min–max bands, not the medians.

## Results Status (crux, native vs SGX enclave, CPU 2; updated Nov 2)

Coarse sweeps: 11 trials. Q4/Q5 step-1 zooms: 21 trials.
Conclusions come from timing; the PMU column is validation run afterwards (`report/pmu_tables.md`).
Native and SGX runs differ in kernel (6.8.0-88 vs 6.8.0-147), chain size (128 vs 40 MiB per chain) and
the timer thread's active core, so compare absolute times with care.

| Q | Native (timing) | SGX enclave (timing) | PMU check |
|---|---|---|---|
| 1 | Independent add IPC 3.99 vs dependent 1.00; imul 1.00 vs 0.333 → pipelined | 4.02 vs 0.99; imul 1.01 vs 0.334 | ✓ IPC 1.001 / 4.03 / 0.334 / 1.004 |
| 2 | 1 miss 360 cyc; 2 dependent 1.96×; 2 indep 1.01×; with consumer 1.02× → out-of-order | 1 miss **615 cyc (+71%)**; 1.99× / 1.13× / 1.14× | – |
| 3 | Random 14.4 cyc/branch vs 3.6–5.2 learnable; degrades from period 256, random-level by 4096 | identical within noise (random 14.25) | ✓ miss rate ≤ 0.00001 (taken, not-taken, alt, period:16) vs 0.4999 (random) |
| 4 | Step-1: half-way crossing **N = 223** → **ROB ≈ 224** (published 224) | identical knee (N = 223), higher plateaus | – |
| 5 | Free int regs **≈ 143–145** (add/andn/shlx; lea forms 138–142); vector **≈ 148**; mix 208 → separate int / vector files | int **≈ 140–142** (lea forms 137–139); vector **≈ 147**; mix 208 | – |
| 14 | 4 instr/cycle; legacy fetch 16 B/cycle | same; largest footprints hold ~16 B/cycle vs ~13 natively | – |
| 15 | **19.4 cyc per mispredict** (`alt` baseline), 20.6 (`period:16`) | **19.0**, 20.3 | ✓ assumptions hold; PMU estimates 18.5–21.6 |

Open on crux: Q3's no-miss patterns cost 3.5–5.0 cycles with no mispredicts, likely front-end
(cause not measured). Q5's mix knee (208) sits below the ROB knee (223) in both modes, unexplained. The Q5
knees sit below published PRF sizes. The enclave's larger miss cost and weaker overlap, compared with
Artemisia's, are not yet explained.

### Still to do
- Optional: Q14 legacy-fetch ceiling (K ≈ 4608), a repeat Artemisia run at a quieter time.
- Final review of `report/report.tex`, final `AI_LOG.md`, and the ZIP.

## AI Use Disclosure

AI was used throughout: Claude Chat helped with the original plan, and Claude Code was used for the harness, experiment runs, analysis, documentation and the report draft. See `AI_LOG.md` for the full log.

## Deliverable

ZIP containing: PDF report, source code, raw data, plotting scripts, reproduction instructions, and AI-use log.
