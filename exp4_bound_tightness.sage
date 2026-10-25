# =============================================================================
# Experiment 4 -- How tight is the bound d < n^(1/4)/3 ?
#   Sweep A: d ~ c * n^(1/4)  for several constants c   (zoom around the bound)
#   Sweep B: d ~ n^alpha      for several exponents alpha
#   Success rate should stay ~100% below the bound and collapse above it.
# Outputs: results/exp4_bound_trials.csv, results/exp4_bound_summary.csv
# Run:     sage exp4_bound_tightness.sage [--quick]
# =============================================================================
import sys
load("wiener_lib.sage")

QUICK  = "--quick" in sys.argv
BITS   = 256 if QUICK else 1024
TRIALS = 10 if QUICK else 100
SEED   = 4242
set_random_seed(SEED)

# (sweep name, parameter value, d_exp, d_scale)
SWEEP_A = [("A_constant", float(c), 0.25, c)
           for c in (0.1, 0.2, 1/3, 0.5, 0.75, 1, 2, 4)]
SWEEP_B = [("B_exponent", a, a, 1)
           for a in (0.20, 0.22, 0.24, 0.25, 0.26, 0.28, 0.30, 0.33, 0.36, 0.40)]

trial_rows, summary_rows = [], []
print(f"{'sweep':>11} {'param':>7} {'success':>8}")
for sweep, param, d_exp, d_scale in SWEEP_A + SWEEP_B:
    wins = 0
    for t in range(TRIALS):
        n, e, d, p, q = generate_weak_key(BITS, d_exp=d_exp, d_scale=d_scale)
        res = wiener_attack(e, n)
        ok = is_correct_recovery(res, d, p, q)
        wins += int(ok)
        trial_rows.append(dict(sweep=sweep, param=param, d_bits=d.nbits(),
                               convergents=res[3], success=int(ok)))
    rate = wins / TRIALS
    summary_rows.append(dict(sweep=sweep, param=param, trials=TRIALS,
                             success_rate=float(rate)))
    print(f"{sweep:>11} {param:>7.3f} {float(rate):>8.2f}", flush=True)

print()
write_csv("results/exp4_bound_trials.csv",
          ["sweep", "param", "d_bits", "convergents", "success"], trial_rows)
write_csv("results/exp4_bound_summary.csv",
          ["sweep", "param", "trials", "success_rate"], summary_rows)
