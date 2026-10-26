# SGX timer probe

Checks whether TSC timing works inside an SGX enclave on this machine. It uses the
**Intel SGX SDK** (`/opt/intel/sgxsdk`, 2.23) with a hardware debug enclave, so it
doesn't depend on Gramine.

## Run
```bash
cd common/sgx/timer_probe
make                          # first run creates ~/.config/sgx/enclave_private.pem (RSA-3072, e=3)
taskset -c 2 ./probe_app      # your session must be in the `sgx` group
```

## What it checks
1. `rdtsc` inside the enclave: does it fault? Is the value consistent with host reads?
2. Back-to-back `rdtsc` deltas inside the enclave, compared with native. A trapped and
   emulated `rdtsc` would show deltas of thousands of ticks.
3. The same 2·10⁷-cycle dependent add chain timed three ways: native, `rdtsc` inside the
   enclave, and the host timing the whole ECALL.
4. The cost of an empty ECALL round trip.

Built **without** the SDK's LVI mitigation (`MITIGATION-CVE-2020-0551`). It inserts
`lfence` after loads, which would distort the out-of-order experiments.

## Result (artemisia, Oct 26, CPU 2)
```
rdtsc in enclave: OK, value within host bracket: yes
back-to-back rdtsc delta in enclave: min 48, median 54 ticks   (native: min 40, median 52)
cycles per TSC tick:  native 1.34312 | rdtsc inside enclave 1.33518 | host times ECALL 1.33550
empty ECALL round trip: 11833 ticks = 15902 cycles
```
- `rdtsc`/`rdtscp` run **natively** inside the enclave on this Sapphire Rapids. There is
  no fault and no emulation; resolution matches native. So the same in-process timing
  and calibration can be used in the enclave.
- The calibration ratio inside the enclave is within 0.6% of native.
- An ECALL costs ~16k cycles. The fallback of timing ECALLs from the host also agrees,
  but only because the work (2·10⁷ cycles) amortizes it to < 0.1%. Any measurement
  timed from outside must be ≫ 16k cycles.
