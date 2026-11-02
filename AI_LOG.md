# AI-Use Log (Track B)

**Tools:**
- Claude Chat (Anthropic): helped with the original plan. Model: Opus 5.5.
- Claude Code (Anthropic), used interactively in the VS Code extension. Model: Claude Opus 5.5
  (`claude-opus-5-5`). The Artemisia session switched to it with `/model opus` early on; any turns before
  that used the session's default model, which the export doesn't record.

**Transcript:** the Artemisia Claude Code session is exported in
`2026-11-01-203701-look-at-hw3-pdf-document-and-help-me-write-a-basi.txt`. The Crux session is summarised
below. The Claude Chat conversation is not included.

The student must review everything listed below and be able to explain it.

## What the AI did, and what the student did

| Date | Area | What the AI did | What the student did |
|------|------|-----------------|----------------------|
| 2026-10 | Planning (Claude Chat) | Helped develop the original plan: question selection, reasoning and fallback | Made the final choice of questions and plan |
| 2026-10 | Planning (Claude Code) | Turned that plan into the README; expanded the experiment and enclave plans | Supplied the plan; checked with the assignment |
| 2026-10 | Machine check | Read `lscpu` and SGX output for Artemisia and recorded it | Provided the machine output; added their account to the `sgx` group with sudo |
| 2026-10 | Harness | Wrote the shared harness: rdtsc calibration, kernels, pointer-chase generator, plotting | Asked for the implementation and directed priorities |
| 2026-10 | Enclave | Tested `rdtsc` in an enclave; wrote the Intel SGX SDK backend after Gramine proved unusable | Chose to build without Gramine |
| 2026-10-26 | Artemisia baseline | Ran all experiments, native and SGX, 11 trials; analysed results; drafted per-question READMEs | Asked whether the data was sufficient and chose next steps |
| 2026-11-01 | Review | Compared the repo with the assignment and listed gaps | Decided priorities |
| 2026-11-01 | Artemisia follow-up | Reorganised results by machine; added Q5 controls, step-1 zooms, PMU scripts, report outline; ran them | Asked for this work; set the policy that PMU only verifies timing results |
| 2026-11-01 | Crux setup | Summarised the Artemisia log; probed SGX (CPUID, EFI variables, kernel config); listed likely SGX on course machines from memory of Intel specs | Supplied the machine list; chose native runs first, with SGX later; set `perf_event_paranoid` with sudo |
| 2026-11-01 | Crux runs | Ran native experiments and PMU checks; found and fixed the no-SMT crash in `common/run_lib.sh`; reran Q1 and Q2 after clock drift | Directed the runs |
| 2026-11-01 | Analysis | Compared Crux with Artemisia; flagged unexplained results; added the Q15 PMU fit | Decided to report differences as findings, with no per-machine code |
| 2026-11-01 | Repo cleanup | Removed PMU data from the Q15 timing plot; added `common/pmu_tables.py`; updated READMEs and outline; committed | Required timing-only results, with PMU as tables afterwards |
| 2026-11-01 | Report | Drafted `report/report.tex` and this log from repo results; | _To do: review, correct and approve_ |

| 2026-11-02 | Packaging | Committed the report and built and tested the submission ZIP | Decided not to pursue SGX on Crux |

## Not done by AI

- The final choice of questions and plan (Claude Chat helped develop them).
- Running sudo commands: `sgx` group membership and `perf_event_paranoid`.
- Decisions on scope, on keeping one implementation across machines, and on the PMU policy.

## Student review (complete before submission)

- [DONE] Read the report and can explain every method and result in it.
- [DONE] Checked the open questions and hypotheses are stated as they should be.
- [DONE] Confirmed this log is accurate, including who selected the questions.

SGX on Crux was not pursued; the report states there was no access to it.

_Add a row for every later AI-assisted step._
