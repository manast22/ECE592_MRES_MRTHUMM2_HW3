# Q14 — Instructions fetched per cycle (10 pts)

## Idea
Run long unrolled blocks of NOPs of each length L = 1 … 15 bytes. NOPs have no
dependencies and do no work, so the front end is the only limit.
- **Short NOPs:** the limit is an *instruction count* per cycle (decode/rename width),
  so IPC flattens and bytes/cycle grows with L.
- **Long NOPs:** the limit is *bytes* per cycle (fetch bandwidth), so bytes/cycle
  flattens and IPC falls as 1/L.

The block size K (NOPs per loop body) decides which front-end path supplies the
instructions:

| footprint | supplied by |
|---|---|
| small K (fits the µop cache) | decoded-µop cache (DSB): measures the µop delivery / rename limit, not fetch |
| more µops than the DSB holds but ≤ 32 KiB | legacy fetch + decode (MITE) from L1i: **this is the fetch-width answer** |
| > 32 KiB (spills L1i) | L2 → L1i refill bandwidth |

## Implementation
| File | What it does |
|---|---|
| `bench/gen_nops.py` | Emits `nop_L_K` for L = 1..15 and K ∈ {256, 2048, 4096, 6144, 8192, 16384}. These are Intel-recommended multi-byte NOPs; lengths over 10 are padded with `0x66` prefixes. |
| `bench/q14_bench.c` | Runs each block about 2·10⁷ instructions per measurement; reports IPC and bytes/cycle. |
| `plots/plot.py` | One figure per result file: IPC vs L and B/cycle vs L, one line per K. |

Code snippet (generated, L = 4, K = 4096):
```asm
nop_4_4096:
1:  .rept 4096
    .byte 0x0f, 0x1f, 0x40, 0x00     # nopl 0x0(%rax)
    .endr
    dec %rdi
    jnz 1b
    ret
```

## How to run
```bash
cd q14_fetch_width/bench
./run.sh native 2
./run.sh sgx 2              # same driver; kernels + data inside an SGX enclave
python3 ../plots/plot.py    # -> plots/q14_fetch_<host>_<mode>.png + IPC/B-per-cycle table
```
CSV columns: `nop_len,count,footprint_bytes,trial,ticks,cycles,instrs,ipc,bytes_per_cycle`.

## Interpreting results
Read the ceilings, and note which path each comes from:
1. IPC ceiling (any K, short NOPs) → front-end/rename width.
2. B/cycle ceiling with K large enough to miss the DSB but footprint ≤ 32 KiB → legacy
   fetch width (the Q14 answer).
3. The flat line once the footprint exceeds L1i is the L2 → L1i bandwidth. It is **not**
   the fetch width; don't report it as such.

Caveat: the DSB holds a limited number of µops per 64 B of code. Very dense code
(1–2-byte NOPs) can bypass it even when the block is small. So for small L the "DSB"
and "legacy" lines coincide.

## Baseline (artemisia, native, CPU 2, 11 trials)
- IPC ceiling ≈ **6.0** (e.g. K = 256, L = 4–10) → 6-wide.
- Legacy path (K = 6144/8192, footprint ≤ 32 KiB): B/cycle rises linearly up to
  **~29 B/cycle** (L = 5, K = 6144, 30 KiB footprint) while IPC stays ≈ 5.8. The ceiling
  wasn't reached before the footprint crossed 32 KiB. So the measured legacy fetch is
  **≥ 29 B/cycle**, consistent with the published 32 B/cycle for Golden Cove.
- µop cache (K = 256): up to ~64 B/cycle. It delivers decoded µops, so this is not fetch.
- Footprint > 32 KiB: flat **12.8 B/cycle** for every L → L2-fed instruction fetch.
  This also marks the L1i size: the drop happens exactly when L·K crosses 32 KiB.

**SGX enclave (same machine, 11 trials):** identical: IPC ceiling 6.0, legacy ~29 B/cycle at L = 5, K = 6144, L2-fed 12.8 B/cycle. Enclave code is fetched from EPC like any other code once cached.

Next step: pin down the legacy ceiling with K just above DSB capacity (e.g. K = 4608,
L = 5–7), keeping the footprint under 32 KiB.

## PMU verification (later)
`idq.dsb_uops` vs `idq.mite_uops` confirm which path each (L, K) point used.
