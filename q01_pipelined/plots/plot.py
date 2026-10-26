#!/usr/bin/env python3
"""Q1: IPC of dependent vs. independent chains, one bar group per result file."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "common"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from plotlib import COLORS, aggregate, load_results, style

VARIANTS = ["add_dep", "add_indep", "imul_dep", "imul_indep"]

data = load_results(os.path.join(HERE, "..", "results"))
if not data:
    sys.exit("no results yet: run ../bench/run.sh first")

fig, ax = plt.subplots(figsize=(7, 4))
width = 0.8 / len(data)
x = np.arange(len(VARIANTS))
print(f"{'series':24s} {'variant':11s} {'IPC med':>8s} {'min':>7s} {'max':>7s}")
for i, (label, d) in enumerate(data.items()):
    agg = aggregate(d["rows"], ["variant"], "ipc")
    med = [agg[(v,)][0] for v in VARIANTS]
    lo = [agg[(v,)][0] - agg[(v,)][1] for v in VARIANTS]
    hi = [agg[(v,)][2] - agg[(v,)][0] for v in VARIANTS]
    ax.bar(x + i * width, med, width * 0.92, yerr=[lo, hi], capsize=3,
           color=COLORS[i], label=label)
    for v in VARIANTS:
        m, a, b, _ = agg[(v,)]
        print(f"{label:24s} {v:11s} {m:8.3f} {a:7.3f} {b:7.3f}")
    add_ratio = agg[("add_indep",)][0] / agg[("add_dep",)][0]
    imul_ratio = agg[("imul_indep",)][0] / agg[("imul_dep",)][0]
    print(f"{label:24s} indep/dep speedup: add x{add_ratio:.2f}, imul x{imul_ratio:.2f}\n")

ax.set_xticks(x + width * (len(data) - 1) / 2)
ax.set_xticklabels(VARIANTS)
style(ax, "Q1 — dependent vs. independent chains", "", "instructions per cycle (median, min–max)")
ax.legend(frameon=False)
fig.tight_layout()
out = os.path.join(HERE, "q1_ipc.png")
fig.savefig(out, dpi=150)
print("wrote", out)
