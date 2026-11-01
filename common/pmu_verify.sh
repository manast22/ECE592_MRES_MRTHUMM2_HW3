#!/bin/bash
# PMU cross-check of the timing-derived results (native runs only: counters are
# not visible inside an enclave). Output: <q>/results/<machine>/pmu/*.txt
# usage: common/pmu_verify.sh [cpu]
# Needs perf and perf_event_paranoid <= 2 (user-space counting). Builds the native
# binaries first if needed. Counter names differ by microarchitecture, so Q4/Q5
# stall events are listed (perf list) rather than hard-coded; see the printed hint.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/run_lib.sh"
CPU=${1:-2}
M=$(machine_name)
command -v perf >/dev/null || { echo "perf not installed" >&2; exit 1; }
echo "perf_event_paranoid=$(cat /proc/sys/kernel/perf_event_paranoid)" >&2

perf_run() {   # perf_run QDIR OUTNAME BINARY ARGS...
    local q=$1 name=$2 bin=$3; shift 3
    local outdir="$REPO_DIR/$q/results/$M/pmu"
    mkdir -p "$outdir"
    ( cd "$REPO_DIR/$q/bench" && make -s >&2 &&
      perf stat -x, -e cycles,instructions,branches,branch-misses -o "$outdir/$name.txt" \
          taskset -c "$CPU" "./$bin" "$@" > /dev/null )
    echo "== $q $name" >&2; cat "$outdir/$name.txt" >&2
}

# Q3: miss rate should be ~0% for the learnable patterns and ~50% for random.
for p in taken alt period:16 period:4096 random; do
    perf_run q03_branch "q3_${p//:/_}" q3_bench -p "$p" -t 3
done
# Q15: measured miss rate for each bias F replaces the assumed min(F,1-F).
for f in 0.05 0.25 0.50; do
    perf_run q15_pipeline_depth "q15_bias_$f" q15_bench -p "bias:$f" -t 3
done
# Q1 / Q14: cycles + instructions give IPC directly.
perf_run q01_pipelined q1_all q1_bench -t 3
perf_run q14_fetch_width q14_all q14_bench -t 3

echo "Q4/Q5: find the ROB / register-file stall events for this CPU with" >&2
echo "  perf list | grep -iE 'resource_stalls|rob|stall'" >&2
echo "then e.g. perf stat -e <event> taskset -c $CPU q04_rob/bench/q4_bench -t 3 -n 400:600:8" >&2
