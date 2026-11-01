#!/bin/bash
# Regenerate every figure.   usage: common/plot_all.sh [machine]
#   no argument -> plots/compare/ (all machines overlaid)
#   machine     -> plots/<machine>/ (that machine only; native + SGX)
cd "$(dirname "$0")/.." || exit 1
for d in q*/plots; do
    for s in "$d"/plot.py "$d"/plot_zoom.py; do
        [ -f "$s" ] || continue
        echo ">> $s $*"
        python3 "$s" "$@" || echo "   (skipped: $s failed or has no data)"
    done
done
