#!/usr/bin/env python3
"""Q2: cycles per loop iteration for one miss, two serial misses, and two
independent misses (back to back, behind a use, and with NOP filler)."""
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


def name(kind, n):
    return {"single": "1 miss", "serial": "2 dependent", "use": "2 indep + use"}.get(
        kind, f"2 indep, {n} nop" if n != "0" else "2 indep")


fig, ax = plt.subplots(figsize=(8, 4))
width = 0.8 / len(data)
for i, (label, d) in enumerate(data.items()):
    agg = aggregate(d["rows"], ["kind", "n"], "cyc_per_iter")
    keys = list(dict.fromkeys((r["kind"], r["n"]) for r in d["rows"]))
    x = np.arange(len(keys))
    med = [agg[k][0] for k in keys]
    err = [[agg[k][0] - agg[k][1] for k in keys], [agg[k][2] - agg[k][0] for k in keys]]
    ax.bar(x + i * width, med, width * 0.92, yerr=err, capsize=3, color=COLORS[i], label=label)
    one = agg[("single", "0")][0]
    print(f"== {label}: 1 miss = {one:.0f} cycles")
    for k in keys:
        print(f"   {name(*k):22s} {agg[k][0]:7.0f} cyc/iter  = {agg[k][0] / one:4.2f} misses")
ax.set_xticks(x + width * (len(data) - 1) / 2)
ax.set_xticklabels([name(*k) for k in keys], rotation=20, ha="right")
style(ax, "Q2 — do two independent misses overlap?", "", "cycles per iteration (median, min–max)")
ax.legend(frameon=False)
fig.tight_layout()
out = os.path.join(HERE, "q2_overlap.png")
fig.savefig(out, dpi=150)
print("wrote", out)
