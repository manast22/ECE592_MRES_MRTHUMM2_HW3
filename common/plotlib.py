"""Shared helpers for the per-experiment plot scripts.

Result files are results/<host>_<mode>.csv: '#' metadata lines, then a CSV
with a header row. Each (host, mode) pair becomes one series.
"""
import csv
import glob
import os
from collections import defaultdict

import numpy as np

# Fixed categorical order (validated palette, light surface); never cycled.
COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948"]
MARKERS = ["o", "s", "^", "D", "v", "P", "X", "*"]


def load_results(results_dir):
    """Return {label: {"meta": {...}, "rows": [dict, ...]}} for every CSV."""
    out = {}
    for path in sorted(glob.glob(os.path.join(results_dir, "*.csv"))):
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
        label = os.path.splitext(os.path.basename(path))[0]
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
