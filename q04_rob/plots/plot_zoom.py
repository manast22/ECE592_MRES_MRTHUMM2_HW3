#!/usr/bin/env python3
"""Q4 step-1 sweep around the ROB knee (results/<machine>/zoom/<mode>.csv)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "common"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from knee import half_cross, knee, sweep
from plotlib import COLORS, load_results, style, plot_dir

data = load_results(os.path.join(HERE, "..", "results"), "zoom")
if not data:
    sys.exit("no zoom results yet: run ../bench/zoom.sh first")

fig, ax = plt.subplots(figsize=(8, 4.2))
for i, (label, d) in enumerate(data.items()):
    ns, med, lo, hi = sweep(d["rows"], "nop")
    a, b, rise = knee(ns, med)
    h = half_cross(ns, med)
    ax.fill_between(ns, lo, hi, color=COLORS[i], alpha=0.15, linewidth=0)
    ax.plot(ns, med, color=COLORS[i], linewidth=2, marker="o", markersize=3,
            label=f"{label}  (half-way at N={h})")
    print(f"{label}: largest step N={a}->{b} (+{rise:.0f} cycles); half-way crossing N={h}")
style(ax, "Q4 — ROB knee, step-1 sweep", "filler instructions between the two loads (N)", "cycles per iteration")
ax.legend(frameon=False, fontsize=8)
fig.tight_layout()
out = os.path.join(plot_dir(HERE), "q4_rob_zoom.png")
fig.savefig(out, dpi=150)
print("wrote", out)
