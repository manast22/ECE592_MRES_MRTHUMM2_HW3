# Report outline (PDF, Track B)

Page 1: title, track, **selected questions and points** (Q1 10, Q2 10, Q3 10, Q15 10,
Q14 10, Q4 30, Q5 35 = 115), machines in one line each, AI-use statement (see AI_LOG.md).

## 1. Machines and setup
- Table: Artemisia (Sapphire Rapids, SGX) and Machine B (TBD): CPU model, microarchitecture,
  cores/SMT, kernel, compiler, SGX yes/no, `perf_event_paranoid`, access limits.
- Measurement method: taskset pin, idle SMT sibling (`sibling_busy_pct` in CSV headers),
  rdtsc → cycles calibration (`cyc_per_tick`), ≥ 10 trials, median + min/max.
- Enclave platform: Intel SGX SDK 2.23, hardware debug enclave, in-enclave rdtsc, static heap
  (no EDMM). Source: `common/sgx/README.md`.

## 2. Per question (same structure each; two machines side by side + native vs enclave)
1. What is tested / how it works (1 paragraph)
2. Code snippet (asm from `qNN/README.md`)
3. Plot (`qNN/plots/*.png`, one figure with both machines)
4. Result table (medians, min–max, trials)
5. Conclusion — **measured** vs **published spec** kept separate
6. Enclave vs native difference and why
7. PMU check (agreement/disagreement; or "counters unavailable on X")

Sections: Q1 pipelined · Q2 out-of-order · Q3 branch prediction · Q15 pipeline depth
(uses Q3 data + PMU miss rate) · Q14 fetch width · Q4 ROB (coarse + step-1 zoom) ·
Q5 PRF (int / ymm / mix + lea / andn controls; zmm if AVX-512).

## 3. Challenges and limitations
- Q5 integer knee (~210) below published 280; what the controls showed.
- Q15 F-dependence of the implied penalty; resolved with `branch-misses`?
- Trial-to-trial bimodality (taken/not-taken 2.0 vs 3.2 cycles; ragged ymm knee).
- Enclave: ECALL cost kept out of timing, perf blocked in enclave, heap size limits.
- Skipped questions and why (TLB/BTB/SMT, see README).

## 4. Reproduction
Point to README.md "Reproduction"; list exact commands used for the submitted CSVs.
