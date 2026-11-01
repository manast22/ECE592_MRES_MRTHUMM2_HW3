#!/bin/bash
# Step-1 sweep around the knee(s) -> ../results/<machine>/zoom/<mode>.csv
# usage: ./zoom.sh [native|sgx] [cpu] [extra bench args...]
#   e.g. ./zoom.sh native 2 -k int,ymm                  (a subset of kinds)
set -euo pipefail
cd "$(dirname "$0")"
source ../../common/run_lib.sh

MODE=${1:-native}
CPU=${2:-2}
shift $(( $# < 2 ? $# : 2 ))

run_bench "$MODE" "$CPU" "../results/$(machine_name)/zoom/${MODE}.csv" q5_bench -t 21 -n 196:460:1 "$@"
