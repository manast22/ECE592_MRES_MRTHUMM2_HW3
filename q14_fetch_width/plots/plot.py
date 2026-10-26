#!/usr/bin/env python3
"""Q14: IPC and bytes/cycle vs. NOP length, one line per block size (K NOPs).
One figure per result file."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "common"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from plotlib import COLORS, MARKERS, aggregate, load_results, style

data = load_results(os.path.join(HERE, "..", "results"))
if not data:
    sys.exit("no results yet: run ../bench/run.sh first")

for label, d in data.items():
    ipc = aggregate(d["rows"], ["count", "nop_len"], "ipc")
    bpc = aggregate(d["rows"], ["count", "nop_len"], "bytes_per_cycle")
    counts = sorted({int(k[0]) for k in ipc})
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.2))
    print(f"== {label}  (rows: K NOPs per block; cols: NOP length; value: IPC / B per cycle)")
    for i, k in enumerate(counts):
        lens = sorted(int(key[1]) for key in ipc if key[0] == str(k))
        y1 = [ipc[(str(k), str(n))][0] for n in lens]
        y2 = [bpc[(str(k), str(n))][0] for n in lens]
        lab = f"K={k}"
        ax1.plot(lens, y1, color=COLORS[i], linewidth=2, marker=MARKERS[i], markersize=4, label=lab)
        ax2.plot(lens, y2, color=COLORS[i], linewidth=2, marker=MARKERS[i], markersize=4, label=lab)
        print(f"   K={k:<6d}" + " ".join(f"{a:4.1f}/{b:4.1f}" for a, b in zip(y1, y2)))
    style(ax1, f"Q14 — instructions per cycle ({label})", "NOP length (bytes)", "instructions per cycle")
    style(ax2, "Bytes per cycle", "NOP length (bytes)", "bytes per cycle")
    ax1.legend(frameon=False, fontsize=8, title="NOPs per block", title_fontsize=8)
    fig.tight_layout()
    out = os.path.join(HERE, f"q14_fetch_{label}.png")
    fig.savefig(out, dpi=150)
    print("wrote", out)
