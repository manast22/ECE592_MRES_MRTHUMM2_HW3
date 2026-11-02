#!/bin/bash
# Run every experiment on this machine, in the right order, then plot.
# usage: common/run_all.sh [cpu] [modes]     e.g. common/run_all.sh 2 "native sgx"
#   modes default: "native", plus "sgx" if this session can open /dev/sgx_enclave.
# Order per mode: coarse runs (all seven questions) -> Q4/Q5 step-1 zooms (their
# windows come from the coarse runs) -> Q5 ymm_state (AVX-512 only).
# Then the PMU checks (native, only if perf works) and all plots.
# Takes roughly 10 min per mode. Failures are reported and the rest continues.
CPU=${1:-2}
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR" || exit 1
if [ -n "${2:-}" ]; then
    MODES=$2
else
    MODES=native
    [ -r /dev/sgx_enclave ] && [ -w /dev/sgx_enclave ] && MODES="native sgx"
fi
failed=()
step() {
    echo ">>> $*" >&2
    "$@" || failed+=("$*")
}

common/preflight.sh "$CPU" || { echo "preflight failed; not running" >&2; exit 1; }
for m in $MODES; do
    for q in q01_pipelined q02_ooo q03_branch q04_rob q05_prf q14_fetch_width q15_pipeline_depth; do
        step "$q/bench/run.sh" "$m" "$CPU"
    done
    step q04_rob/bench/zoom.sh "$m" "$CPU"
    step q05_prf/bench/zoom.sh "$m" "$CPU"
    step q05_prf/bench/ymm_state.sh "$m" "$CPU"
done
if perf stat -e branch-misses:u true >/dev/null 2>&1; then
    step common/pmu_verify.sh "$CPU"
else
    echo "perf counting unavailable: skipping PMU verification" >&2
fi
step common/plot_all.sh

echo "== done on $(hostname -s) (modes: $MODES)" >&2
if [ ${#failed[@]} -gt 0 ]; then
    printf 'FAILED: %s\n' "${failed[@]}" >&2
    exit 1
fi
