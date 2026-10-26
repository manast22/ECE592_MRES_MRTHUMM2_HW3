"""Knee detection and plotting for the filler sweeps (Q4 ROB, Q5 PRF)."""
import numpy as np

from plotlib import aggregate


def sweep(rows, kind):
    """Return (n, median, min, max) arrays for one filler kind, sorted by n."""
    agg = aggregate([r for r in rows if r["kind"] == kind], ["n"], "cyc_per_iter")
    ns = sorted(int(k[0]) for k in agg)
    a = np.array([agg[(str(n),)][:3] for n in ns])
    return np.array(ns), a[:, 0], a[:, 1], a[:, 2]


def knee(ns, med):
    """Largest single-step rise in the median curve. Returns (n_before, n_after,
    rise). The second miss stops overlapping somewhere in (n_before, n_after]."""
    d = np.diff(med)
    i = int(np.argmax(d))
    return ns[i], ns[i + 1], d[i]
