#!/usr/bin/env python3
"""Q5: cycles per iteration vs. register-writing filler count, per filler kind.
One panel per result file. Q4's NOP curve (if present) is drawn as a reference."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "common"))
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from knee import knee, sweep
from plotlib import COLORS, load_results, style

KINDS = {"int": "integer (add r,r)", "ymm": "vector (vpaddd ymm)", "mix": "alternating int / ymm"}

data = load_results(os.path.join(HERE, "..", "results"))
if not data:
    sys.exit("no results yet: run ../bench/run.sh first")
rob = load_results(os.path.join(HERE, "..", "..", "q04_rob", "results"))

fig, axes = plt.subplots(len(data), 1, figsize=(8, 4.2 * len(data)), squeeze=False)
for ax, (label, d) in zip(axes[:, 0], data.items()):
    print(f"== {label}")
    if label in rob:
        ns, med, _, _ = sweep(rob[label]["rows"], "nop")
        ax.plot(ns, med, color="#8a8984", linewidth=1.2, linestyle="--", label="nop (Q4, ROB)")
    for i, (kind, desc) in enumerate(KINDS.items()):
        ns, med, lo, hi = sweep(d["rows"], kind)
        a, b, rise = knee(ns, med)
        ax.fill_between(ns, lo, hi, color=COLORS[i], alpha=0.15, linewidth=0)
        ax.plot(ns, med, color=COLORS[i], linewidth=2, label=f"{desc}  (knee {a}–{b})")
        print(f"   {kind:4s}: largest jump between N={a} and N={b} (+{rise:.0f} cycles)")
    style(ax, f"Q5 — register-writing filler ({label})", "filler instructions between the two loads (N)",
          "cycles per iteration")
    ax.legend(frameon=False, fontsize=8)
fig.tight_layout()
out = os.path.join(HERE, "q5_prf.png")
fig.savefig(out, dpi=150)
print("wrote", out)
