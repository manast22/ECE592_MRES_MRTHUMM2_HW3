# Q1 — Is the processor pipelined? (10 pts)

## Idea
Run the same instruction as **one dependency chain** and as **8 independent chains**.
A dependent chain can never beat 1/latency instructions per cycle. If the independent
version runs faster than that, several instructions are in flight at once, so the
processor is pipelined (and, for add, superscalar).

`imul` is the cleaner test. It has a 3-cycle latency and only one multiply port. If
independent imuls still issue at 1 per cycle, a new multiply enters the unit each cycle
while older ones are still in progress, so the unit itself is pipelined.

## Implementation
| File | What it does |
|---|---|
| `bench/kernels.S` | `add_dep`, `add_indep`, `imul_dep`, `imul_indep`: a 1000-instruction unrolled block (`.rept`) looped `iters` times. Register operands only (no immediates), so rename cannot collapse the chain. |
| `bench/q1_bench.c` | Calibrates TSC→cycles, then times each variant `-t` times (trials outermost, variants interleaved). |
| `plots/plot.py` | Bar chart of IPC (median, min–max error bars) + speedup table. |

Code snippet (the core of the experiment):
```asm
add_dep:   .rept 1000            add_indep: .rept 125
           add %rdx, %rax                  add %rdx, %rax
           .endr                           add %rdx, %rbx   ... 8 registers
                                           .endr
```

## How to run
```bash
cd q01_pipelined/bench
./run.sh native 2          # mode (native|sgx), CPU to pin to
./run.sh sgx 2             # kernels run inside an SGX enclave (see common/sgx/README.md)
python3 ../plots/plot.py   # -> plots/q1_ipc.png + table on stdout
```
Bench flags: `-t trials` (default 11), `-i iters` (×1000 instructions, default 20000).

## Run flow
`run.sh` → `make` → `run_bench` (pins with `taskset`, checks that the SMT sibling is
idle, records machine info in `machines/`) → `q1_bench` → `results/<host>_<mode>.csv`.

CSV columns: `variant,trial,ticks,cycles,instrs,cpi,ipc`. The `# calib` line gives the
TSC→cycle ratio; `# recheck` gives the drift at the end of the run.

## Interpreting results
- `add_dep` IPC ≈ 1.0 by construction (the calibration *is* a dependent add chain).
- `add_indep` IPC ≫ 1 → overlapping execution (pipelined + multiple ALUs).
- `imul_dep` ≈ 0.33 (3-cycle latency); `imul_indep` ≈ 1.0 → the multiplier accepts
  a new op every cycle while each takes 3 → pipelined functional unit.
- The calibration's own sanity check (`imul_latency_cyc` ≈ 3.0) also validates the cycle conversion.

## Baseline (artemisia, native, CPU 2, 11 trials)
| variant | IPC (median) |
|---|---|
| add_dep | 1.01 |
| add_indep | 4.79 (×4.7) |
| imul_dep | 0.338 |
| imul_indep | 1.01 (×3.0) |

The add speedup of ~4.8 is close to Golden Cove's 5 integer ALU ports (published
spec, not measured here).

**SGX enclave (same machine, 11 trials):** identical. add_indep 4.72, add_dep 1.00, imul_dep 0.333, imul_indep 1.00. Pipelining is a core property; the enclave doesn't touch it.

## PMU verification (later)
`perf stat -e cycles,instructions` on `q1_bench` should reproduce the same IPC.
