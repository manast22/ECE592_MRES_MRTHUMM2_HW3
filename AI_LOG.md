# AI-Use Log (Track B)

Tool: Claude Code (Anthropic), used interactively in the VS Code extension. Exact model
names/versions: _fill in before submission_. The student must review everything listed
below and be able to explain it.

| Date | Area | What the AI did | What the student did / checked |
|------|------|-----------------|--------------------------------|
| 2026-10 | Planning | Proposed the question selection (Q1–5, Q14, Q15), experiment plan and enclave plan | Chose questions, checked against Homework_3.pdf |
| 2026-10 | Harness | Drafted the shared harness (rdtsc calibration, kernels, pointer-chase generator, SGX backend) | Built and ran it on Artemisia, examined output |
| 2026-10-26 | Baseline | Helped analyse baseline native vs SGX results; drafted per-question READMEs | Ran all experiments (11 trials), verified numbers |
| 2026-11-01 | Review | Compared repo against the assignment; listed gaps | Decided priorities |
| 2026-11-01 | Repo | Reorganised results into `results/<machine>/<mode>.csv` with automatic routing; added Q5 control kernels, step-1 zoom sweeps, PMU script, report outline | _to do: run and review_ |
| 2026-11-01 | Crux setup | Probed SGX state (CPUID, EFI variables, kernel config) and summarised what the Artemisia log left to do; listed which course machines should have SGX, from memory of Intel specs | Chose to run native first and enable SGX later; set `perf_event_paranoid` with sudo |
| 2026-11-01 | Crux runs | Ran the native experiments and PMU checks on crux; found and fixed a crash on machines without SMT (`common/run_lib.sh`); reran Q1 and Q2 after clock drift | _to do: review results_ |
| 2026-11-01 | Analysis | Compared crux with artemisia; flagged unexplained results; added the Q15 PMU fit | _to do: review; explain open items_ |
| 2026-11-01 | Repo | Removed PMU data from the Q15 timing plot; added `common/pmu_tables.py` so PMU is validation only; updated READMEs and outline | Decided PMU stays separate, as tables after the fact |

Not done by AI: running benchmarks on the course machines, interpreting final results,
writing the final report text (update this line if that changes).

_Add a row for every later AI-assisted step (report drafting, debugging, plots)._
