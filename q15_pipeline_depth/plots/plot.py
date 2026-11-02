#!/usr/bin/env python3
"""Q15: mispredict penalty from timing alone (no PMU needed).

Anchor: for i.i.d. fair-coin outcomes (bias:0.50 / random) EVERY predictor
mispredicts exactly half the time in expectation, because the outcome is
independent of everything it can observe. With `alt` as the baseline
(same 50/50 path mix, perfectly predicted -- it sits on the same minimum cost
as period:16), the penalty is exact:
    P = (t(0.5) - t_alt) / 0.5            (period:16 baseline shown as a check)

Biased coins (F < 0.5) only have a LOWER bound on the miss rate: the best
possible predictor mispredicts min(F, 1-F), a real one at least that. So
    (t(F) - base(F)) / min(F, 1-F)       is an UPPER bound on P,
and, given P, the timing implies the actual miss rate:
    miss(F) = (t(F) - base(F)) / P
base(F) is the perfectly predicted cost at path mix F, interpolated between
the all-one-way cost (the lower median of `taken` / `nottaken`) and `alt`.
Those two flip between ~2.0 and ~3.2 cycles per trial (a front-end effect, not
prediction), which makes base(F) uncertain by a few tenths of a cycle at small F.
The headline P uses only `alt` and the fair coin, so it is unaffected.

This script reads timing results only. PMU validation is separate: plot_pmu.py
and common/pmu_tables.py.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "common"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from plotlib import COLORS, MARKERS, aggregate, load_results, style, plot_dir

data = load_results(os.path.join(HERE, "..", "results"))
if not data:
    sys.exit("no results yet: run ../bench/run.sh first")

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.2))
for i, (label, d) in enumerate(data.items()):
    agg = aggregate(d["rows"], ["pattern"], "cyc_per_branch")
    t = {k[0]: v[0] for k, v in agg.items()}
    t_one, t_alt = min(t["taken"], t["nottaken"]), t["alt"]
    P = (t["bias:0.50"] - t_alt) / 0.5
    P16 = (t["bias:0.50"] - t["period:16"]) / 0.5
    fs = sorted(float(p[5:]) for p in t if p.startswith("bias:") and 0 < float(p[5:]) <= 0.5)

    print(f"== {label}: PENALTY = (t_random {t['bias:0.50']:.3f} - t_alt {t_alt:.3f}) / 0.5 = {P:.1f} cycles"
          f"  (period:16 baseline: {P16:.1f})")
    print("   F     t(F)   base   upper-bound P   implied miss rate")
    implied = []
    for f in fs:
        tf = t[f"bias:{f:.2f}"]
        base = t_one + 2 * f * (t_alt - t_one)
        implied.append((tf - base) / P)
        print(f"   {f:4.2f}  {tf:6.2f} {base:6.2f}   {(tf - base) / f:10.1f}   {implied[-1]:14.3f}")

    ax1.plot(fs, [t[f"bias:{f:.2f}"] for f in fs], color=COLORS[i], linewidth=2,
             marker=MARKERS[i], markersize=5, label=f"{label}  (P = {P:.1f} cycles)")
    ax2.plot(fs, implied, color=COLORS[i], linewidth=2, marker=MARKERS[i], markersize=5,
             label=f"{label}, from timing")

ax2.plot([0, 0.5], [0, 0.5], color="#8a8984", linestyle="--", linewidth=1.2,
         label="best possible predictor: min(F, 1−F)")
style(ax1, "Q15 — cost vs. taken probability", "taken probability F", "cycles per branch (median)")
style(ax2, "Miss rate implied by timing (penalty from F = 0.5)", "taken probability F",
      "mispredicts per branch")
ax1.legend(frameon=False, fontsize=8)
ax2.legend(frameon=False, fontsize=8)
fig.tight_layout()
out = os.path.join(plot_dir(HERE), "q15_penalty.png")
fig.savefig(out, dpi=150)
print("wrote", out)
