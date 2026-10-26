#!/bin/bash
# usage: ./run.sh [native|sgx] [cpu] [extra bench args...]
set -euo pipefail
cd "$(dirname "$0")"
source ../../common/run_lib.sh

MODE=${1:-native}
CPU=${2:-2}
shift $(( $# < 2 ? $# : 2 ))

# Predictable baselines (all one way, and 50/50 but learnable) plus a sweep of
# i.i.d. taken-probability; the predictor's best guess mispredicts ~min(F,1-F).
PATTERNS="taken,nottaken,alt,period:16"
for f in 0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50; do
    PATTERNS+=",bias:$f"
done

run_bench "$MODE" "$CPU" "../results/$(hostname -s)_${MODE}.csv" q15_bench -t 11 -p "$PATTERNS" "$@"
