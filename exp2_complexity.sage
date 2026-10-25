# =============================================================================
# Experiment 2 -- Complexity versus key size
#   For each modulus size, run many trials on weak keys at the provable bound
#   and record (i) number of convergents tested, (ii) running time.
# Outputs: results/exp2_complexity_trials.csv   (one row per trial)
#          results/exp2_complexity_summary.csv  (one row per size = report table)
# Run:     sage exp2_complexity.sage [--quick] [--big]
#          --big adds 8192-bit keys (key generation becomes slow)
# =============================================================================
import sys
load("wiener_lib.sage")

QUICK  = "--quick" in sys.argv
BIG    = "--big" in sys.argv
SIZES  = [256, 512, 1024] if QUICK else [256, 512, 1024, 2048, 4096]
if BIG:
    SIZES.append(8192)
TRIALS = 5 if QUICK else 50
SEED   = 2024
set_random_seed(SEED)

trial_rows, summary_rows = [], []
for bits in SIZES:
    print(f"[{bits} bits] running {TRIALS} trials ...", flush=True)
    stats = []
    for t in range(TRIALS):
        n, e, d, p, q = generate_weak_key(bits)

        # 1) one call to check correctness + count convergents (deterministic)
        res = wiener_attack(e, n)
        ok = is_correct_recovery(res, d, p, q)
        tested = res[3]

        # 2) time the attack only (key generation is NOT included)
        secs = time_call(wiener_attack, e, n)

        stats.append((int(ok), tested, secs))
        trial_rows.append(dict(bits=bits, n_bits=n.nbits(), d_bits=d.nbits(),
                               convergents=tested, time_s=secs, success=int(ok)))

    succ = sum(s[0] for s in stats) / len(stats)
    conv_m, conv_s = mean_std([s[1] for s in stats])
    time_m, time_s = mean_std([s[2] * 1000 for s in stats])      # in ms
    summary_rows.append(dict(bits=bits, trials=TRIALS, success_rate=float(succ),
                             avg_convergents=conv_m, std_convergents=conv_s,
                             avg_time_ms=time_m, std_time_ms=time_s))

# ---- pretty table for the report -------------------------------------------
print("\n| bits | trials | success | avg convergents | avg time (ms) |")
print("|-----:|-------:|--------:|----------------:|--------------:|")
for r in summary_rows:
    print(f"| {r['bits']} | {r['trials']} | {r['success_rate']*100:.0f}% | "
          f"{r['avg_convergents']:.1f} ± {r['std_convergents']:.1f} | "
          f"{r['avg_time_ms']:.3f} ± {r['std_time_ms']:.3f} |")

print()
write_csv("results/exp2_complexity_trials.csv",
          ["bits", "n_bits", "d_bits", "convergents", "time_s", "success"], trial_rows)
write_csv("results/exp2_complexity_summary.csv",
          ["bits", "trials", "success_rate", "avg_convergents", "std_convergents",
           "avg_time_ms", "std_time_ms"], summary_rows)
