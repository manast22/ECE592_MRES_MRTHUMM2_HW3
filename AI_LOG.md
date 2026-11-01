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

Not done by AI: running benchmarks on the course machines, interpreting final results,
writing the final report text (update this line if that changes).

_Add a row for every later AI-assisted step (report drafting, debugging, plots)._
