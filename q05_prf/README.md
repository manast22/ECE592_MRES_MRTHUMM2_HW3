# Q5 — Physical register file size and register class (35 pts)

## Idea
Same loop as Q4, but every filler instruction **writes a register**. Every in-flight
register write holds a physical register until it retires. If the physical registers
run out before the ROB does, the knee moves to a smaller N. The knee position then
gives the number of *free* physical registers of that class.

Filler choices:
- `int`: `add %rX, %rX` rotating over 10 integer registers. This is not a zeroing
  idiom and not a `mov`, so rename cannot eliminate it, and each chain is short
  (2N/10), so it never becomes the bottleneck.
- `ymm`: `vpaddd %ymm0, %ymm0, %ymmK` writes ymm1..15. Every instruction is
  independent because ymm0 is never written.
- Controls (added Nov 1): `int_andn`, `int_shlx`, `int_lea2`, `int_lea`, `int_ind`. These vary
  flags-writing, chains and immediates (see Results), plus `ymm_hi` (see `ymm_state.sh`).
- `mix`: alternating `int` / `ymm`. If the two classes share **one** register file, the
  knee stays at ≈ the smaller single-class knee. If they are **separate**, each file
  fills at half the rate and the knee moves to ≈ 2× the int knee, capped by the ROB.

Avoided: `xor r,r` / `vpxor` zeroing idioms and `mov r,r`. Both can be handled at rename
without allocating a register.

## Implementation
The same harness as Q2/Q4 (`common/chase/`), generated with
`--kinds int,ymm,mix --n 0:640:8`.

| File | What it does |
|---|---|
| `bench/Makefile` | Generates `kernels.S`, links `q5_bench`. |
| `plots/plot.py` | One panel per result file: int / ymm / mix curves plus Q4's NOP curve as a dashed reference (if Q4 results exist for the same host/mode). |

Code snippet (`int` filler, N = 3):
```asm
1:  mov (%rax), %rax       # miss A
    add %r8, %r8           # each writes a fresh physical register
    add %r9, %r9
    add %r10, %r10
    mov (%rcx), %rcx       # miss B
    ...
```

## How to run
```bash
cd q05_prf/bench
./run.sh native 2           # coarse grid, all filler kinds, 11 trials (~1 min)
./run.sh sgx 2              # same driver; kernels + data inside an SGX enclave
./zoom.sh native 2          # step-1 windows N = 196-280 and 404-460, 21 trials (~2.5 min)
./zoom.sh sgx 2
./ymm_state.sh native 2     # ymm vs ymm_hi (ymm16-31 written first), N = 220-280
./ymm_state.sh sgx 2
make xinuse && ./xinuse     # is ymm16-31 state in use? (enclave: common/sgx/timer_probe/probe_app)
python3 ../plots/plot.py       # -> plots/compare/q5_prf.png + knees on stdout
python3 ../plots/plot_zoom.py  # -> plots/compare/q5_prf_zoom.png + halfway crossings
```
Run Q4 first if you want the NOP reference line on the plot. Outputs:
`results/<machine>/{<mode>.csv, zoom/<mode>.csv, ymm_state/<mode>.csv}`.

## Interpreting results
- Knee(int) < knee(NOP) → the integer PRF limits the window before the ROB does.
  Free int registers ≈ N_knee + 1, because load A also writes a register. Total PRF ≈
  free + architectural state held by committed values (16 GPRs plus internal and
  flag-related registers). Report it as a lower bound.
- Knee(ymm) gives the same for the vector PRF.
- Knee(mix) ≈ 2 × knee(int) → integer and vector are **separate register classes**. Where
  2 × knee(int) is beyond the ROB (crux: 2 × 145 vs. 224), the ROB should cap it first, so
  the test is simply knee(mix) well above both single-class knees.
- Native vs SGX: knee positions should match.

Crux (no AVX-512): native int family 138–145, ymm 148, mix 208; SGX int family 137–142, ymm 147,
mix 208. `int_lea` and `int_ind` hit the same limit as `add`, unlike artemisia. **Open:** mix at
208 is about 15 short of the ROB knee (223) in both modes, with no explanation yet; separate
classes still hold.

## Results (artemisia, Nov 1; coarse step 8 × 11 trials + step-1 zoom × 21 trials, native and SGX)

Each value is the median over trials of the **per-trial halfway crossing** in the step-1 zoom
(`plots/plot_zoom.py`; the window is N = 196–280, or 404–460 for mix).

| filler | writes | native | SGX | reading |
|---|---|---|---|---|
| nop (Q4) | nothing | 498 | 498 | ROB ≈ 500 |
| `add r,r` (int) | GPR + flags | **214** | **215** | integer PRF |
| `andn` (independent) | GPR + flags | 213 | 212 | same: chains don't matter |
| `shlx` (independent) | GPR only, no imm | 207 | 208 | same: **flags don't matter** |
| `lea (r,r)` | GPR only, no imm | 213 | 212 | same |
| `lea 1(r)`, `lea 1(rbp)` | GPR only, **reg+imm** | no PRF knee: runs to the ROB (~496) | same | **allocates no physical register** |
| `vpaddd ymm` | vector | **244** | **262** | vector PRF (see below) |
| `ymm_hi` (ymm after writing ymm16–31) | vector | 241 | **244** | explains the SGX difference |
| mix int / ymm | both, alternating | 426 | 429 | ≈ 2 × int → **separate files** |

Conclusions:
1. **Integer PRF:** ~**210 ± 4** free entries are available to in-flight integer writes. It
   is the same for flag-writing (`add`, `andn`) and flags-free (`shlx`, `lea r,r`) writers, so
   flags are not a separate limit here. Free ≠ total: committed architectural state (this
   thread's 16 GPRs, and on an SMT core the idle sibling's state too) also occupies
   entries. So total int PRF ≳ 210 + 16. Published: 280. Report the measured free count, and
   say the total is a lower bound.
2. **`lea reg+imm` is handled at rename:** with that filler the window is limited only by the
   ROB. So Golden Cove does not allocate a physical register for a register-plus-small-immediate
   `lea`, presumably by folding the immediate into the rename mapping. This is also why every
   other benchmark here uses register-register forms (`add r,r` in the calibration).
3. **Separate classes:** the mix knee (426–429) is about twice the int knee and well below the
   ROB. The int and vector writes fill different structures; with one shared file the mix knee
   would match the int knee.
4. **Vector PRF and the native-vs-SGX difference:** natively ~244 free vector entries; inside
   the enclave ~262 (19 of 21 trials each in the zoom). Two pieces of evidence point to
   architectural state rather than an enclave effect on the hardware:
   - **Knee (`ymm_state.sh`):** writing ymm16–31 before the sweep moves the enclave's median
     knee from 263 to 244 (12 of 21 trials exactly at 244, the rest spread up to 263) and changes
     nothing natively (241 vs 241).
   - **In-use bits (`xinuse.c`, `results/<machine>/ymm_state/xinuse.txt`):** `xgetbv(1)` bit 7
     (zmm16–31 in use) is 1 in a default native process, already at the start of `main`; 0 with
     glibc's AVX-512 paths disabled through `GLIBC_TUNABLES`; and 0 in the enclave. So glibc
     (including the startup code that runs before `main`) is what leaves those registers in use.

   Still unconfirmed: the matching native sweep with `GLIBC_TUNABLES` set. It should move the
   native knee up to ~262. The one run so far gave a median of 255 (most trials 253–270), but
   another user's job was loading the machine, and the default-setting runs in that same
   session were noisy too (medians 207 and 229). Repeat it when Artemisia is quiet before citing it.

Earlier coarse-grid notes (still valid): the native ymm transition looked ragged across
240–272. With 21 trials at step 1 it is a clean step at 241–244 in 19 of 21 trials; the
remaining trials resemble the enclave state.

## PMU verification (later)
`resource_stalls.*` / `rat_stalls` style events (event names vary by generation;
check `perf list`) should show the stall source switching from ROB to register file.
