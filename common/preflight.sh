#!/bin/bash
# Check a machine before running the experiments on it.
# usage: common/preflight.sh [cpu]       (cpu = the core you plan to pin to; default 2)
# Prints OK / WARN / FAIL lines; exit status 1 if a native run cannot work.
CPU=${1:-2}
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO_DIR/common/run_lib.sh"
fail=0
ok()   { printf '  OK    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; fail=1; }
flag() { grep -m1 '^flags' /proc/cpuinfo | grep -qw "$1"; }

echo "== machine: $(machine_name)"
echo "   $(lscpu | sed -n 's/^Model name: *//p')  (family $(lscpu | sed -n 's/^CPU family: *//p'), model $(lscpu | sed -n 's/^Model: *//p'))"
echo "   record the microarchitecture name for this family/model in the top-level README"

echo "== tools"
for t in gcc make python3 taskset; do command -v $t >/dev/null && ok "$t" || bad "$t not found"; done
python3 -c "import numpy, matplotlib" 2>/dev/null && ok "python3 numpy + matplotlib" \
    || warn "python3 numpy/matplotlib missing: benchmarks run, plots won't (pip3 install --user numpy matplotlib)"

echo "== CPU features"
flag avx2 && ok "avx2 (needed by every pointer-chase kernel, Q2/Q4/Q5)" || bad "no avx2: Q2/Q4/Q5 kernels will fault"
flag bmi1 && ok "bmi1 (Q5 int_andn control)" || warn "no bmi1: Q5 int_andn control is not built"
flag bmi2 && ok "bmi2 (Q5 int_shlx control)" || warn "no bmi2: Q5 int_shlx control is not built"
flag avx512vl && ok "avx512vl (Q5 ymm_hi / ymm_state.sh)" || warn "no avx512vl: Q5 ymm_hi and ymm_state.sh are skipped (expected on non-AVX-512 CPUs)"
flag constant_tsc && flag nonstop_tsc && ok "constant + nonstop TSC" || warn "TSC not constant/nonstop: rdtsc timing may be unreliable"

echo "== CPU $CPU"
allowed=$(taskset -cp $$ 2>/dev/null | sed 's/.*: //')
if taskset -c "$CPU" true 2>/dev/null; then ok "can pin to cpu $CPU (allowed: $allowed)"; else bad "cannot pin to cpu $CPU (allowed: $allowed); pass another cpu"; fi
sib=$(tr ',-' '\n\n' < "/sys/devices/system/cpu/cpu$CPU/topology/thread_siblings_list" 2>/dev/null | grep -vx "$CPU" | head -1)
[ -n "$sib" ] && ok "SMT sibling of cpu $CPU is cpu $sib (keep it idle; run.sh reports its load)" || ok "cpu $CPU has no SMT sibling"

echo "== memory hierarchy (Q2/Q4/Q5 use two 128 MiB pointer chains)"
llc=""
for idx in /sys/devices/system/cpu/cpu$CPU/cache/index*; do
    [ "$(cat $idx/level 2>/dev/null)" -ge 3 ] 2>/dev/null && llc=$(cat $idx/size)
done
if [ -n "$llc" ]; then
    kb=$(echo "$llc" | awk '/K$/{print int($0)} /M$/{print int($0)*1024}')
    if [ -z "$kb" ]; then
        warn "could not parse LLC size '$llc'; check that it is well below 128 MiB"
    elif [ "$kb" -ge $((128 * 1024 / 2)) ]; then
        warn "LLC $llc is not much smaller than a 128 MiB chain: raise it (q0*/bench/run.sh ... -s 512) and ENCLAVE_HEAP for SGX"
    else
        ok "LLC $llc per cpu $CPU, well below 128 MiB per chain"
    fi
else
    warn "could not read the LLC size from sysfs; check lscpu"
fi
avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
[ "${avail:-0}" -gt 1024 ] && ok "${avail} MiB memory available" || warn "only ${avail} MiB memory available"

echo "== SGX (optional: enclave comparison)"
if [ ! -e /dev/sgx_enclave ]; then
    warn "no /dev/sgx_enclave: SGX disabled/unsupported here; run native only and report it"
else
    [ -r /dev/sgx_enclave ] && [ -w /dev/sgx_enclave ] && ok "/dev/sgx_enclave accessible" \
        || warn "/dev/sgx_enclave exists but this session can't open it (needs the 'sgx' group, then a new login)"
    sdk=${SGX_SDK:-/opt/intel/sgxsdk}
    [ -x "$sdk/bin/x64/sgx_sign" ] && ok "Intel SGX SDK in $sdk" \
        || warn "Intel SGX SDK not found in $sdk (set SGX_SDK=... for make)"
    echo "  NOTE  if the EPC can't hold two 128 MiB chains, use common/run_sgx1.sh for sgx mode"
    command -v openssl >/dev/null && ok "openssl (enclave signing key)" || warn "openssl missing: cannot create the signing key"
fi

echo "== PMU (optional: verification only)"
if command -v perf >/dev/null; then
    p=$(cat /proc/sys/kernel/perf_event_paranoid)
    if perf stat -e branch-misses:u true >/dev/null 2>&1; then ok "perf user-space counting works (paranoid=$p)"
    else warn "perf present but counting failed (paranoid=$p): skip pmu.sh / pmu_verify.sh"; fi
else
    warn "perf not installed: skip pmu.sh / pmu_verify.sh"
fi

[ $fail -eq 0 ] && echo "== ready: common/run_all.sh $CPU" || echo "== fix the FAIL lines first"
exit $fail
