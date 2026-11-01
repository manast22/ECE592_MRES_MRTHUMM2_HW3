#!/usr/bin/env python3
"""Q5 step-1 sweeps around the register-file knees (results/<machine>/zoom/<mode>.csv).
One panel per result file, one curve per filler kind, restricted to the windows
that were swept at step 1."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "common"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from knee import half_cross, sweep
from plotlib import COLORS, load_results, style, plot_dir

data = load_results(os.path.join(HERE, "..", "results"), "zoom")
if not data:
    sys.exit("no zoom results yet: run ../bench/zoom.sh first")

fig, axes = plt.subplots(len(data), 1, figsize=(8, 4.2 * len(data)), squeeze=False)
for ax, (label, d) in zip(axes[:, 0], data.items()):
    print(f"== {label}")
    kinds = sorted({r["kind"] for r in d["rows"]})
    for i, kind in enumerate(kinds):
        ns, med, lo, hi = sweep(d["rows"], kind)
        h = half_cross(ns, med, window=5)
        ax.fill_between(ns, lo, hi, color=COLORS[i % 8], alpha=0.15, linewidth=0)
        ax.plot(ns, med, color=COLORS[i % 8], linewidth=1.6, marker="o", markersize=2.5,
                label=f"{kind}  (half-way N={h})")
        spread = float(np.median(hi - lo))
        print(f"   {kind:9s}: N {ns[0]}..{ns[-1]}  half-way crossing N={h}  median min-max spread {spread:.0f} cycles")
    style(ax, f"Q5 — step-1 sweep ({label})", "filler instructions between the two loads (N)", "cycles per iteration")
    ax.legend(frameon=False, fontsize=8)
fig.tight_layout()
out = os.path.join(plot_dir(HERE), "q5_prf_zoom.png")
fig.savefig(out, dpi=150)
print("wrote", out)
