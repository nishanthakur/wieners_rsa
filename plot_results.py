"""
plot_results.py -- turns the CSV files in results/ into report figures.

Plain Python (needs numpy + matplotlib); no Sage required:
    python3 plot_results.py
Figures are saved to figures/ as PNG and PDF.  Missing CSVs are skipped.
"""
import csv
import os
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")                 # no display needed
import matplotlib.pyplot as plt
import numpy as np

os.makedirs("figures", exist_ok=True)


def read_csv(path):
    """Read a CSV into a list of dicts; return None if the file is missing."""
    if not os.path.exists(path):
        print(f"[skip] {path} not found")
        return None
    with open(path) as f:
        return list(csv.DictReader(f))


def group_by(rows, key, value):
    """Return {key: [float(value), ...]} sorted by key."""
    out = defaultdict(list)
    for r in rows:
        out[float(r[key])].append(float(r[value]))
    return dict(sorted(out.items()))


def save(fig, name):
    for ext in ("png", "pdf"):
        fig.savefig(f"figures/{name}.{ext}", dpi=200, bbox_inches="tight")
    print("saved figures/%s.(png|pdf)" % name)
    plt.close(fig)


# ---------------------------------------------------------------- Figure 1 ---
def fig_complexity():
    rows = read_csv("results/exp2_complexity_trials.csv")
    if rows is None:
        return
    conv = group_by(rows, "bits", "convergents")
    secs = group_by(rows, "bits", "time_s")
    bits = np.array(list(conv))
    conv_m = np.array([np.mean(v) for v in conv.values()])
    conv_s = np.array([np.std(v) for v in conv.values()])
    ms_m = np.array([np.mean(v) * 1000 for v in secs.values()])
    ms_s = np.array([np.std(v) * 1000 for v in secs.values()])

    fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 3.8))

    # (a) convergents vs key size: should be linear in log n
    a1.errorbar(bits, conv_m, conv_s, fmt="o-", capsize=3, label="measured")
    slope, icpt = np.polyfit(bits, conv_m, 1)
    a1.plot(bits, slope * bits + icpt, "--", color="gray",
            label=f"linear fit ({slope:.3f}·bits)")
    # Heuristic: Euclid's algorithm needs ~0.843·ln(D) steps to reach a
    # denominator D (Levy); here D ~ n^(1/4)  =>  ~0.146·bits steps.
    a1.plot(bits, 0.146 * bits, ":", color="C3", label="estimate 0.146·bits")
    a1.set_xlabel("modulus size (bits)")
    a1.set_ylabel("convergents tested")
    a1.set_title("(a) Convergents tested")
    a1.legend()
    a1.grid(alpha=.3)

    # (b) time vs key size on log-log axes: slope = polynomial degree
    a2.errorbar(bits, ms_m, ms_s, fmt="o-", capsize=3, label="measured")
    k, c = np.polyfit(np.log2(bits), np.log2(ms_m), 1)
    a2.plot(bits, 2 ** c * bits ** k, "--", color="gray",
            label=f"fit: time ∝ bits^{k:.2f}")
    a2.set_xscale("log", base=2)
    a2.set_yscale("log", base=2)
    a2.set_xlabel("modulus size (bits)")
    a2.set_ylabel("running time (ms)")
    a2.set_title("(b) Running time (log-log)")
    a2.legend()
    a2.grid(alpha=.3, which="both")
    print(f"[exp2] convergents ≈ {slope:.3f}·bits;  time ∝ bits^{k:.2f}")
    save(fig, "fig1_complexity")


# ---------------------------------------------------------------- Figure 2 ---
def fig_bruteforce():
    rows = read_csv("results/exp3_bruteforce.csv")
    if rows is None:
        return
    w_t = group_by(rows, "bits", "wiener_time_s")
    b_t = group_by(rows, "bits", "bf_time_s")
    w_c = group_by(rows, "bits", "wiener_convergents")
    b_c = group_by(rows, "bits", "bf_candidates")
    bits = np.array(list(w_t))

    fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 3.8))
    a1.semilogy(bits, [np.mean(v) * 1000 for v in w_t.values()], "o-", label="Wiener")
    a1.semilogy(bits, [np.mean(v) * 1000 for v in b_t.values()], "s-", label="brute force")
    a1.set_xlabel("modulus size (bits)")
    a1.set_ylabel("time (ms)")
    a1.set_title("(a) Running time")
    a1.legend()
    a1.grid(alpha=.3, which="both")

    wc = np.array([np.mean(v) for v in w_c.values()])
    bc = np.array([np.mean(v) for v in b_c.values()])
    a2.semilogy(bits, wc, "o-", label="Wiener: convergents")
    a2.semilogy(bits, bc, "s-", label="brute force: candidates")
    slope = np.polyfit(bits, np.log2(bc), 1)[0]
    a2.set_title(f"(b) Work (brute force ≈ 2^({slope:.2f}·bits))")
    a2.set_xlabel("modulus size (bits)")
    a2.set_ylabel("candidates / convergents tested")
    a2.legend()
    a2.grid(alpha=.3, which="both")
    print(f"[exp3] brute-force work grows as 2^({slope:.3f}·bits)  (theory: 0.25)")
    save(fig, "fig2_wiener_vs_bruteforce")


# ---------------------------------------------------------------- Figure 3 ---
def fig_bound():
    rows = read_csv("results/exp4_bound_summary.csv")
    if rows is None:
        return
    A = [(float(r["param"]), float(r["success_rate"]) * 100)
         for r in rows if r["sweep"] == "A_constant"]
    B = [(float(r["param"]), float(r["success_rate"]) * 100)
         for r in rows if r["sweep"] == "B_exponent"]

    fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 3.8))
    a1.semilogx(*zip(*A), "o-")
    a1.axvline(1 / 3, color="C3", ls="--", label="theorem: c = 1/3")
    a1.set_xlabel("c   (d ≈ c · n^{1/4})")
    a1.set_ylabel("success rate (%)")
    a1.set_title("(a) Zoom around the bound")
    a1.legend()
    a1.grid(alpha=.3, which="both")

    a2.plot(*zip(*B), "o-")
    a2.axvline(0.25, color="C3", ls="--", label="theorem: α = 1/4")
    a2.axvline(0.292, color="C2", ls=":", label="Boneh–Durfee: α ≈ 0.292")
    a2.set_xlabel("α   (d ≈ n^α)")
    a2.set_ylabel("success rate (%)")
    a2.set_title("(b) Success vs. exponent of d")
    a2.legend()
    a2.grid(alpha=.3)
    save(fig, "fig3_bound_tightness")


if __name__ == "__main__":
    fig_complexity()
    fig_bruteforce()
    fig_bound()
