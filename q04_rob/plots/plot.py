#!/usr/bin/env python3
"""Q4: cycles per iteration vs. NOP filler count; the knee is the ROB size."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "common"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from knee import knee, sweep
from plotlib import COLORS, MARKERS, load_results, style

data = load_results(os.path.join(HERE, "..", "results"))
if not data:
    sys.exit("no results yet: run ../bench/run.sh first")

fig, ax = plt.subplots(figsize=(8, 4.5))
for i, (label, d) in enumerate(data.items()):
    ns, med, lo, hi = sweep(d["rows"], "nop")
    a, b, rise = knee(ns, med)
    ax.fill_between(ns, lo, hi, color=COLORS[i], alpha=0.15, linewidth=0)
    ax.plot(ns, med, color=COLORS[i], linewidth=2, marker=MARKERS[i], markersize=3,
            label=f"{label}  (knee {a}–{b})")
    ax.axvline(b, color=COLORS[i], linewidth=1, linestyle=":")
    print(f"{label}: largest jump between N={a} and N={b} (+{rise:.0f} cycles) "
          f"-> ROB estimate ~{b} entries (+2 loads, +1 loop branch per window)")
style(ax, "Q4 — miss / N NOPs / independent miss", "filler NOPs between the two loads (N)",
      "cycles per iteration (median, band = min–max)")
ax.legend(frameon=False)
fig.tight_layout()
out = os.path.join(HERE, "q4_rob.png")
fig.savefig(out, dpi=150)
print("wrote", out)
