#!/bin/bash
# Step-1 sweep around the ROB knee -> ../results/<machine>/zoom/<mode>.csv
# The window is derived from this machine's coarse run (run.sh first), or set it:
#   ZOOM=200:260 ./zoom.sh native 2
# usage: ./zoom.sh [native|sgx] [cpu] [extra bench args...]
set -euo pipefail
cd "$(dirname "$0")"
source ../../common/run_lib.sh

MODE=${1:-native}
CPU=${2:-2}
shift $(( $# < 2 ? $# : 2 ))

zoom_setup "$MODE" nop 470:530
run_bench "$MODE" "$CPU" "../results/$(machine_name)/zoom/${MODE}.csv" q4_bench -t 21 -n "$ZOOM_N" "$@"
