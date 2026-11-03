#!/bin/bash
# Run every experiment in SGX mode on a small-EPC SGX1 machine, then plot.
# usage: common/run_sgx1.sh [cpu] [MiB per chain]
#   Needs SGX_SDK set to the SDK, and the real uRTS on LD_LIBRARY_PATH if the PSW
#   is not installed system-wide (the SDK's own libsgx_urts.so is only a stub).
# common/run_all.sh's 128 MiB chains (288 MiB heap) would page on such a machine:
# Q2/Q4/Q5 use smaller chains here, sized to fit the EPC and still well above the LLC.
# Takes the knees for the Q4/Q5 zoom windows from this machine's native coarse runs.
CPU=${1:-2}
MB=${2:-40}
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR" || exit 1
HEAP=$(printf '0x%x' $(( (2 * MB + 4) * 1024 * 1024 )))
echo "chains: ${MB} MiB each, enclave heap ${HEAP}" >&2

failed=()
step() {
    echo ">>> $*" >&2
    "$@" || failed+=("$*")
}
for q in q01_pipelined q03_branch q14_fetch_width q15_pipeline_depth; do
    step "$q/bench/run.sh" sgx "$CPU"
done
export ENCLAVE_HEAP=$HEAP
for q in q02_ooo q04_rob q05_prf; do
    step "$q/bench/run.sh" sgx "$CPU" -s "$MB"
done
step q04_rob/bench/zoom.sh sgx "$CPU" -s "$MB"
step q05_prf/bench/zoom.sh sgx "$CPU" -s "$MB"
step q05_prf/bench/ymm_state.sh sgx "$CPU" -s "$MB"
unset ENCLAVE_HEAP
step common/plot_all.sh
step common/plot_all.sh "${MACHINE:-$(hostname -s)}"

echo "== done on $(hostname -s) (sgx)" >&2
if [ ${#failed[@]} -gt 0 ]; then
    printf 'FAILED: %s\n' "${failed[@]}" >&2
    exit 1
fi
