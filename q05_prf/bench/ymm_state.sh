#!/bin/bash
# Does in-use upper vector state (ymm16-31) explain the native-vs-SGX ymm knee?
# Runs `ymm` and `ymm_hi` (same filler, ymm16-31 written first) at step 1 around
# this machine's ymm knee. Needs AVX-512VL (ymm16-31 exist only with AVX-512).
# -> ../results/<machine>/ymm_state/<mode>.csv
# usage: ./ymm_state.sh [native|sgx] [cpu]
set -euo pipefail
cd "$(dirname "$0")"
source ../../common/run_lib.sh

MODE=${1:-native}
CPU=${2:-2}
shift $(( $# < 2 ? $# : 2 ))

if ! grep -qw avx512vl /proc/cpuinfo; then
    echo "skipped: $(machine_name) has no AVX-512VL, so there are no ymm16-31 registers to test" >&2
    exit 0
fi
zoom_setup "$MODE" ymm 220:280
run_bench "$MODE" "$CPU" "../results/$(machine_name)/ymm_state/${MODE}.csv" q5_bench -t 21 -k ymm,ymm_hi -n "$ZOOM_N" "$@"
