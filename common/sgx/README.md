# SGX backend (Intel SGX SDK, no Gramine)

Every experiment can run its timed part inside an SGX enclave with
`./run.sh sgx <cpu>`. The host driver (CLI, data generation, CSV output) is the same
code in both modes. Only the backend linked into it changes.

```
            native (q1_bench)                 sgx (q1_bench_sgx)
 driver ──► kb_native.c ──► kt_* ──► kernels   driver ──► kb_sgx.c ══ECALL══► enclave_main.c ──► kt_* ──► kernels
                                                               (q1_bench_sgx.enclave.so)
```

| File | Role |
|---|---|
| `../kt.h` | Kernel-side interface: `kt_count`, `kt_entry`, `kt_setup`, `kt_run`. Each experiment implements it once (`q1_kt.c`, `chase_kt.c`, `q3_kt.c`, `q14_kt.c`); that file is compiled into both builds. |
| `../kbackend.h`, `../kb_native.c` | Host API, plus the native implementation (direct calls). |
| `kb.edl` | ECALL interface: `ecall_count/entry/setup/run/calib`. |
| `enclave_main.c` | Enclave side: forwards ECALLs to `kt_*`; times the calibration chains. |
| `kb_sgx.c` | Host side: creates `<exe>.enclave.so` and makes the ECALLs. |
| `sgx.mk` | Build rules (`make sgx`): edger8r, enclave link, signing. |
| `enclave.config.xml.in`, `enclave.lds` | Enclave config (heap = `ENCLAVE_HEAP`), symbol export list. |
| `timer_probe/` | Standalone check that `rdtsc` works inside the enclave. |

## What runs where
- **Inside the enclave:** the kernels; the `rdtsc` reads around them; the calibration
  chains; and the test data.
  - Pointer chains are built in the enclave heap.
  - Branch patterns are copied in through `ecall_setup`.
  - So Q2/Q4/Q5 misses go to encrypted EPC memory.
- **Outside:** argument parsing, pattern generation, printing.
  - An ECALL costs ~16k cycles, but it is never inside a timed region.

## Configuration to report
- Intel SGX SDK 2.23 (`/opt/intel/sgxsdk`), hardware mode, **debug** enclave (`DisableDebug=0`).
  It is signed with a self-generated key (`~/.config/sgx/enclave_private.pem`, RSA-3072, e=3),
  which works because the platform has flexible launch control (`sgx_lc`).
- Static heap (no EDMM / SGX2 dynamic memory): the whole heap is added at enclave creation.
  Heap size per experiment is `ENCLAVE_HEAP` in its `bench/Makefile`.
- 4 KB EPC pages only (no huge pages in enclaves); native runs also use 4 KB (`-H` off).
- **LVI mitigation off:** the SDK's `MITIGATION-CVE-2020-0551` option would insert `lfence`
  after loads, serializing the loads the OoO experiments measure. A production enclave
  would normally enable it, and that would change the Q2/Q4/Q5 results.
- Interrupts during a measurement cause an AEX (asynchronous enclave exit) and re-entry,
  which costs more than a native interrupt. This adds occasional outliers; medians absorb them.

## Requirements
The login session must be in the `sgx` group (`/dev/sgx_enclave` is `root:sgx` 0660).
`run.sh sgx` checks this and explains what to do if access is missing.
