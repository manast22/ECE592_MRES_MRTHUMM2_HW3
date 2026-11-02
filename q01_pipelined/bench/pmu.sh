#!/bin/bash
# PMU verification for Q1 (native only): IPC per variant from cycles:u and
# instructions:u, by the difference method (-i 40000 minus -i 20000), compared
# against the TSC-derived IPC. -> ../results/<machine>/pmu/native.csv
# usage: ./pmu.sh [cpu]
set -euo pipefail
cd "$(dirname "$0")"
source ../../common/run_lib.sh
source ../../common/pmu_lib.sh

CPU=${1:-2}
TRIALS=3
EVENTS=cycles:u,instructions:u

make -s
out="../results/$(machine_name)/pmu/native.csv"
mkdir -p "$(dirname "$out")"
{
    echo "# host $(machine_name) mode native cpu $CPU date $(date -Is) method=diff(-i 40000 minus -i 20000) trials=$TRIALS"
    echo "variant,d_cycles,d_instructions,pmu_ipc"
    for v in add_dep add_indep imul_dep imul_indep; do
        declare -A a=() b=()
        for kv in $(pmu_count "$CPU" "$EVENTS" ./q1_bench -t $TRIALS -i 20000 -v $v); do a[${kv%%=*}]=${kv#*=}; done
        for kv in $(pmu_count "$CPU" "$EVENTS" ./q1_bench -t $TRIALS -i 40000 -v $v); do b[${kv%%=*}]=${kv#*=}; done
        dc=$(( b[cycles] - a[cycles] )); di=$(( b[instructions] - a[instructions] ))
        echo "$v,$dc,$di,$(awk -v i=$di -v c=$dc 'BEGIN{printf "%.4f", i/c}')"
    done
} > "$out"
echo "wrote $out" >&2
