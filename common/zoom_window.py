#!/usr/bin/env python3
"""Pick step-1 zoom windows from a machine's own coarse sweep.

usage: zoom_window.py COARSE_CSV KINDS PAD
  COARSE_CSV  results/<machine>/<mode>.csv from run.sh (kind,n,...,cyc_per_iter)
  KINDS       comma list of filler kinds whose knee should be zoomed (e.g. int,ymm,mix)
  PAD         filler counts to add on each side of the coarse knee

Prints the windows as "lo:hi[,lo:hi...]" (overlaps merged), or nothing if no
kind has a real knee (the median must rise by >= 40%, as in knee.half_cross).
Used by zoom.sh so the step-1 sweep follows each machine's own knees instead of
Sapphire Rapids' (ROB ~500, int PRF ~210).
"""
import csv
import statistics
import sys
from collections import defaultdict


def main():
    path, kinds, pad = sys.argv[1], sys.argv[2].split(","), int(sys.argv[3])
    with open(path) as f:
        rows = list(csv.DictReader(l for l in f if not l.startswith("#")))
    windows = []
    for kind in kinds:
        by_n = defaultdict(list)
        for r in rows:
            if r["kind"] == kind:
                by_n[int(r["n"])].append(float(r["cyc_per_iter"]))
        if len(by_n) < 4:
            continue
        ns = sorted(by_n)
        med = [statistics.median(by_n[n]) for n in ns]
        steps = [med[i + 1] - med[i] for i in range(len(med) - 1)]
        i = max(range(len(steps)), key=steps.__getitem__)
        if med[-1] - med[0] < 0.4 * med[0]:
            continue   # no knee in range (e.g. lea reg+imm filler)
        windows.append([max(0, ns[i] - pad), ns[i + 1] + pad])
    windows.sort()
    merged = []
    for w in windows:
        if merged and w[0] <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], w[1])
        else:
            merged.append(w)
    print(",".join(f"{lo}:{hi}" for lo, hi in merged))


if __name__ == "__main__":
    main()
