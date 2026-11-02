#!/bin/bash
# PMU verification for Q3/Q15 (native only): measured branch-miss rate and
# PMU cycles per data branch for each pattern, by the difference method:
#   run with -n 4 and -n 8 timed passes; delta = TRIALS * 4 * LEN data branches.
# -> ../results/<machine>/pmu/native.csv
# usage: ./pmu.sh [cpu]
set -euo pipefail
cd "$(dirname "$0")"
source ../../common/run_lib.sh
source ../../common/pmu_lib.sh

CPU=${1:-2}
TRIALS=3
LEN=$((1 << 20))
EVENTS=branches:u,branch-misses:u,cycles:u,instructions:u
PATTERNS="nottaken taken alt period:16 random"
for f in 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50; do PATTERNS+=" bias:$f"; done

make -s
out="../results/$(machine_name)/pmu/native.csv"
mkdir -p "$(dirname "$out")"
{
    echo "# host $(machine_name) mode native cpu $CPU date $(date -Is) method=diff(-n 8 minus -n 4) trials=$TRIALS len=$LEN"
    echo "pattern,data_branches,d_branches,d_branch_misses,d_cycles,d_instructions,miss_rate,pmu_cyc_per_branch"
    for p in $PATTERNS; do
        declare -A a=() b=()
        for kv in $(pmu_count "$CPU" "$EVENTS" ./q15_bench -t $TRIALS -n 4 -p "$p"); do a[${kv%%=*}]=${kv#*=}; done
        for kv in $(pmu_count "$CPU" "$EVENTS" ./q15_bench -t $TRIALS -n 8 -p "$p"); do b[${kv%%=*}]=${kv#*=}; done
        n=$(( TRIALS * 4 * LEN ))
        db=$(( b[branches] - a[branches] )); dm=$(( b[branch-misses] - a[branch-misses] ))
        dc=$(( b[cycles] - a[cycles] )); di=$(( b[instructions] - a[instructions] ))
        echo "$p,$n,$db,$dm,$dc,$di,$(awk -v m=$dm -v n=$n 'BEGIN{printf "%.5f", m/n}'),$(awk -v c=$dc -v n=$n 'BEGIN{printf "%.4f", c/n}')"
        echo "  $p done" >&2
    done
} > "$out"
echo "wrote $out" >&2
