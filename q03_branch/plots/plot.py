#!/usr/bin/env python3
"""Q3: cycles per branch for each pattern, one bar group per result file."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "common"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from plotlib import COLORS, aggregate, load_results, style

data = load_results(os.path.join(HERE, "..", "results"))
if not data:
    sys.exit("no results yet: run ../bench/run.sh first")

first = next(iter(data.values()))["rows"]
patterns = list(dict.fromkeys(r["pattern"] for r in first))

fig, ax = plt.subplots(figsize=(9, 4.2))
width = 0.8 / len(data)
x = np.arange(len(patterns))
for i, (label, d) in enumerate(data.items()):
    agg = aggregate(d["rows"], ["pattern"], "cyc_per_branch")
    med = [agg[(p,)][0] for p in patterns]
    err = [[agg[(p,)][0] - agg[(p,)][1] for p in patterns], [agg[(p,)][2] - agg[(p,)][0] for p in patterns]]
    ax.bar(x + i * width, med, width * 0.92, yerr=err, capsize=2, color=COLORS[i], label=label)
    print(f"== {label}")
    for p in patterns:
        print(f"   {p:14s} {agg[(p,)][0]:6.2f} cycles/branch")
ax.set_xticks(x + width * (len(data) - 1) / 2)
ax.set_xticklabels(patterns, rotation=30, ha="right")
style(ax, "Q3 — cost of one data-dependent branch by pattern", "", "cycles per branch (median, min–max)")
ax.legend(frameon=False)
fig.tight_layout()
out = os.path.join(HERE, "q3_branch.png")
fig.savefig(out, dpi=150)
print("wrote", out)
