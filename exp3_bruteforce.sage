# =============================================================================
# Experiment 3 -- Wiener's attack vs. brute force over d < n^(1/4)/3
#   Brute force needs about n^(1/4)/3 = 2^(bits/4) candidates (exponential in
#   the key size); Wiener needs O(log n) convergents (polynomial).
#   Only SMALL moduli are used because brute force explodes quickly.
# Output: results/exp3_bruteforce.csv
# Run:    sage exp3_bruteforce.sage [--quick]
# =============================================================================
import sys
load("wiener_lib.sage")

QUICK  = "--quick" in sys.argv
SIZES  = [32, 40, 48, 56, 64] if QUICK else [32, 40, 48, 56, 64, 72, 80]
TRIALS = 3 if QUICK else 10
SEED   = 777
set_random_seed(SEED)

rows = []
print(f"{'bits':>5} {'wiener conv.':>13} {'wiener ms':>10} {'brute cand.':>12} {'brute ms':>10}")
for bits in SIZES:
    acc = []
    for _ in range(TRIALS):
        n, e, d, p, q = generate_weak_key(bits)
        bound = d_upper_bound(n)            # attacker only knows this bound

        # Wiener
        res = wiener_attack(e, n)
        assert is_correct_recovery(res, d, p, q), "Wiener failed on a weak key!"
        w_time = time_call(wiener_attack, e, n, min_time=0.02)

        # Brute force (candidates tried == recovered d, since we count up from 1)
        d_bf = brute_force_d(e, n, bound)
        assert d_bf is not None
        bf_time = time_call(brute_force_d, e, n, bound, min_time=0.02)

        rows.append(dict(bits=bits, n_bits=n.nbits(), d=d,
                         wiener_convergents=res[3], wiener_time_s=w_time,
                         bf_candidates=d_bf, bf_time_s=bf_time))
        acc.append((res[3], w_time * 1000, d_bf, bf_time * 1000))
    avg = [sum(col) / len(acc) for col in zip(*acc)]
    print(f"{bits:>5} {float(avg[0]):>13.1f} {float(avg[1]):>10.4f} "
          f"{float(avg[2]):>12.0f} {float(avg[3]):>10.3f}", flush=True)

write_csv("results/exp3_bruteforce.csv",
          ["bits", "n_bits", "d", "wiener_convergents", "wiener_time_s",
           "bf_candidates", "bf_time_s"], rows)
