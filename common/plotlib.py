"""Shared helpers for the per-experiment plot scripts.

Result files are results/<machine>/<mode>.csv: '#' metadata lines, then a CSV
with a header row. Each (machine, mode) pair becomes one series, labelled
'<machine>_<mode>'.
"""
import csv
import glob
import os
import sys
from collections import defaultdict

import numpy as np

# Optional first command-line argument of every plot script: a machine name.
#   plot.py            -> all machines overlaid, written to plots/compare/
#   plot.py artemisia  -> only that machine,      written to plots/artemisia/
MACHINE = sys.argv[1] if len(sys.argv) > 1 else None


def plot_dir(here):
    """Output directory for the figures of the plot script living in `here`."""
    d = os.path.join(here, MACHINE or "compare")
    os.makedirs(d, exist_ok=True)
    return d


# Fixed categorical order (validated palette, light surface); never cycled.
COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"]
MARKERS = ["o", "s", "^", "D", "v", "P", "X", "*"]


def load_results(results_dir, sub=""):
    """Return {label: {"meta": {...}, "rows": [dict, ...]}} for every CSV.
    sub="zoom" reads results/<machine>/zoom/<mode>.csv instead (step-1 sweeps)."""
    out = {}
    for path in sorted(glob.glob(os.path.join(results_dir, "*", sub, "*.csv"))):
        meta, lines = {}, []
        with open(path) as f:
            for line in f:
                if line.startswith("#"):
                    parts = line[1:].split()
                    if parts and parts[0] == "calib":
                        for kv in parts[1:]:
                            k, v = kv.split("=")
                            meta[k] = float(v)
                    elif parts and parts[0] == "host":
                        it = iter(parts)
                        meta.update(dict(zip(it, it)))
                elif line.strip():
                    lines.append(line)
        rows = list(csv.DictReader(lines))
        machine_dir = os.path.dirname(os.path.dirname(path)) if sub else os.path.dirname(path)
        if MACHINE and os.path.basename(machine_dir) != MACHINE:
            continue
        label = (os.path.basename(machine_dir) + "_"
                 + os.path.splitext(os.path.basename(path))[0])
        out[label] = {"meta": meta, "rows": rows}
    return out


def aggregate(rows, keys, value):
    """Group rows by `keys`; return {key_tuple: (median, min, max, n)}."""
    groups = defaultdict(list)
    for r in rows:
        groups[tuple(r[k] for k in keys)].append(float(r[value]))
    return {k: (float(np.median(v)), min(v), max(v), len(v)) for k, v in groups.items()}


def style(ax, title, xlabel, ylabel):
    ax.set_title(title, loc="left", fontsize=11)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.grid(True, color="#e4e3df", linewidth=0.6)
    ax.set_axisbelow(True)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
