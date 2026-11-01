#!/bin/bash
# Step-1 sweep around the knee(s) -> ../results/<machine>/zoom/<mode>.csv
# usage: ./zoom.sh [native|sgx] [cpu] [extra bench args...]
#   e.g. ./zoom.sh native 2 -n 404:460:1 -k mix        (a different window / kind)
set -euo pipefail
cd "$(dirname "$0")"
source ../../common/run_lib.sh

MODE=${1:-native}
CPU=${2:-2}
shift $(( $# < 2 ? $# : 2 ))

run_bench "$MODE" "$CPU" "../results/$(machine_name)/zoom/${MODE}.csv" q4_bench -t 21 -n 470:530:1 "$@"
