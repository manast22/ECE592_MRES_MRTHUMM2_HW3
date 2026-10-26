#!/usr/bin/env python3
"""Q15: mispredict penalty from the taken-probability sweep.

Baseline cost of a perfectly predicted branch at taken fraction F is
interpolated between `nottaken` (F=0) and `alt` (F=0.5, predictable but with
the same path mix as random). A predictor that guesses the majority direction
mispredicts min(F, 1-F) of the time (verify later with the branch-misses PMU
counter), so
    penalty(F) = (t(F) - base(F)) / min(F, 1-F)
"""
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

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.2))
for i, (label, d) in enumerate(data.items()):
    agg = aggregate(d["rows"], ["pattern"], "cyc_per_branch")
    t_nt, t_alt = agg[("nottaken",)][0], agg[("alt",)][0]
    fs, ts, pens = [], [], []
    for (p,), (m, _, _, _) in sorted(agg.items()):
        if p.startswith("bias:"):
            fs.append(float(p[5:]))
            ts.append(m)
    order = sorted(range(len(fs)), key=fs.__getitem__)
    fs, ts = [fs[j] for j in order], [ts[j] for j in order]
    print(f"== {label}: nottaken {t_nt:.2f}, alt {t_alt:.2f} cycles/branch")
    print("   F     t(F)   base   penalty")
    pf = []
    for f, t in zip(fs, ts):
        base = t_nt + 2 * min(f, 1 - f) * (t_alt - t_nt)
        rate = min(f, 1 - f)
        if rate > 0:
            pen = (t - base) / rate
            pf.append(f)
            pens.append(pen)
            print(f"   {f:4.2f}  {t:6.2f} {base:6.2f} {pen:7.1f}")
    ax1.plot(fs, ts, color=COLORS[i], linewidth=2, marker=MARKERS[i], markersize=5, label=label)
    ax2.plot(pf, pens, color=COLORS[i], linewidth=2, marker=MARKERS[i], markersize=5, label=label)
    print(f"   penalty at F=0.5 (random): {pens[-1]:.1f} cycles; at smallest F: {pens[0]:.1f} cycles")

style(ax1, "Q15 — cost vs. taken probability", "taken probability F", "cycles per branch (median)")
style(ax2, "Implied cycles lost per mispredict", "taken probability F", "cycles per mispredict")
ax1.legend(frameon=False)
fig.tight_layout()
out = os.path.join(HERE, "q15_penalty.png")
fig.savefig(out, dpi=150)
print("wrote", out)
