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

# Q3 + Q15: per-pattern branch-miss rate and PMU cycles/branch, difference
# method (8 minus 4 timed passes) -> q15_pipeline_depth/results/$M/pmu/native.csv
"$REPO_DIR/q15_pipeline_depth/bench/pmu.sh" "$CPU"
# Q1: per-variant IPC, difference method -> q01_pipelined/results/$M/pmu/native.csv
"$REPO_DIR/q01_pipelined/bench/pmu.sh" "$CPU"
# Q14: whole-process cycles + instructions (aggregate IPC only).
perf_run q14_fetch_width q14_all q14_bench -t 3
# Timing vs. counters for Q1, Q3 and Q15 -> report/pmu_tables.md
python3 "$REPO_DIR/common/pmu_tables.py"

echo "Q4/Q5: find the ROB / register-file stall events for this CPU with" >&2
echo "  perf list | grep -iE 'resource_stalls|rob|stall'" >&2
echo "then e.g. perf stat -e <event> taskset -c $CPU q04_rob/bench/q4_bench -t 3 -n 400:600:8" >&2
