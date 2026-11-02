#!/bin/bash
# Step-1 sweeps around the register-file knees -> ../results/<machine>/zoom/<mode>.csv
# Windows are derived from this machine's coarse run (int, ymm and mix knees; run.sh
# first), or set them:   ZOOM=140:200,280:330 ./zoom.sh native 2
# usage: ./zoom.sh [native|sgx] [cpu] [extra bench args...]
#   e.g. ./zoom.sh native 2 -k int,ymm                  (a subset of kinds)
set -euo pipefail
cd "$(dirname "$0")"
source ../../common/run_lib.sh

MODE=${1:-native}
CPU=${2:-2}
shift $(( $# < 2 ? $# : 2 ))

zoom_setup "$MODE" int,ymm,mix 196:280,404:460
run_bench "$MODE" "$CPU" "../results/$(machine_name)/zoom/${MODE}.csv" q5_bench -t 21 -n "$ZOOM_N" "$@"
