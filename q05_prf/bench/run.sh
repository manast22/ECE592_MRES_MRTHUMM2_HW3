#!/bin/bash
# usage: ./run.sh [native|sgx] [cpu] [extra bench args...]
set -euo pipefail
cd "$(dirname "$0")"
source ../../common/run_lib.sh

MODE=${1:-native}
CPU=${2:-2}
shift $(( $# < 2 ? $# : 2 ))

run_bench "$MODE" "$CPU" "../results/$(hostname -s)_${MODE}.csv" q5_bench -t 11 "$@"
