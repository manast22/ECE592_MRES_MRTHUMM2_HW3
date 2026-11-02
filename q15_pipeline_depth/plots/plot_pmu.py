#!/usr/bin/env python3
"""Q15 PMU verification (results/<machine>/pmu/native.csv from ../bench/pmu.sh).

Everything here comes from the difference method (8 minus 4 timed passes), so
setup and warm-up cancel. Two estimates of the mispredict penalty:
    assumed:  (c(F) - base(F)) / min(F, 1-F)       (what plot.py does from timing)
    measured: (c(F) - base(F)) / miss_rate(F)       (miss rate from branch-misses:u)
with c(F) = PMU cycles per data branch and base(F) interpolated between the
perfectly predicted `nottaken` (F=0) and `alt` (F=0.5) runs. That base(F) is too
high at small F where `alt` costs more than the other no-miss patterns (crux), so
those per-F values read low. A straight-line fit of c(F) against the measured miss
rate needs no baseline: its slope is the penalty.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "common"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from plotlib import COLORS, MARKERS, load_results, style, plot_dir

data = load_results(os.path.join(HERE, "..", "results"), "pmu")
if not data:
    sys.exit("no PMU results yet: run ../bench/pmu.sh first")

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.2))
for i, (label, d) in enumerate(data.items()):
    rows = {r["pattern"]: r for r in d["rows"]}
    c = {p: float(r["pmu_cyc_per_branch"]) for p, r in rows.items()}
    m = {p: float(r["miss_rate"]) for p, r in rows.items()}
    c_nt, c_alt = c["nottaken"], c["alt"]
    print(f"== {label}: miss rate nottaken {m['nottaken']:.4f}, alt {m['alt']:.4f}, "
          f"period:16 {m['period:16']:.4f}, random {m['random']:.4f}")
    print("   F     miss(assumed) miss(measured)  cyc/branch  penalty(assumed) penalty(measured)")
    fs, meas, pa, pm = [], [], [], []
    for p in sorted((p for p in rows if p.startswith("bias:")), key=lambda p: float(p[5:])):
        f = float(p[5:])
        rate = min(f, 1 - f)
        base = c_nt + 2 * rate * (c_alt - c_nt)
        fs.append(f)
        meas.append(m[p])
        pa.append((c[p] - base) / rate)
        pm.append((c[p] - base) / m[p])
        print(f"   {f:4.2f}  {rate:12.3f} {m[p]:14.4f} {c[p]:11.2f} {pa[-1]:16.1f} {pm[-1]:17.1f}")
    pr = (c["random"] - c_alt) / m["random"]
    print(f"   random: penalty(measured) {pr:.1f}")
    print(f"   penalty(measured) over F: median {np.median(pm):.1f}, range {min(pm):.1f}-{max(pm):.1f} cycles")
    slope, intercept = np.polyfit(meas, [c[f"bias:{f:.2f}"] for f in fs], 1)
    print(f"   fit c(F) vs miss rate: slope {slope:.1f} cycles per mispredict, intercept {intercept:.2f}")

    ax1.plot(fs, [min(f, 1 - f) for f in fs], color="#8a8984", linestyle="--", linewidth=1.2,
             label="assumed: min(F, 1−F)")
    ax1.plot(fs, meas, color=COLORS[i], linewidth=2, marker=MARKERS[i], markersize=5,
             label=f"measured ({label})")
    ax2.plot(fs, pa, color="#8a8984", linestyle="--", linewidth=1.2, marker="o", markersize=4,
             label="using assumed miss rate")
    ax2.plot(fs, pm, color=COLORS[i], linewidth=2, marker=MARKERS[i], markersize=5,
             label=f"using measured miss rate ({label})")

style(ax1, "Q15 — branch-miss rate (PMU)", "taken probability F", "mispredicts per data branch")
style(ax2, "Implied cycles lost per mispredict", "taken probability F", "cycles per mispredict")
ax2.set_ylim(bottom=0)
ax1.legend(frameon=False, fontsize=8)
ax2.legend(frameon=False, fontsize=8)
fig.tight_layout()
out = os.path.join(plot_dir(HERE), "q15_pmu.png")
fig.savefig(out, dpi=150)
print("wrote", out)
