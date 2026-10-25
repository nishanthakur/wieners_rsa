# =============================================================================
# Experiment 1 -- Correctness
#   (a) On weak keys (d < n^(1/4)/3) the attack must succeed 100% of the time.
#   (b) On standard keys (e = 65537) the attack must fail (negative control).
# Output: results/exp1_correctness.csv
# Run:    sage exp1_correctness.sage [--quick]
# =============================================================================
import sys
load("wiener_lib.sage")

QUICK  = "--quick" in sys.argv
SIZES  = [128, 256, 512, 1024] if QUICK else [128, 256, 512, 1024, 2048]
TRIALS = 10 if QUICK else 100
SEED   = 12345
set_random_seed(SEED)

rows = []
print(f"{'bits':>6} {'key type':>10} {'trials':>7} {'recovered':>10} {'rate':>7}")
for bits in SIZES:
    for key_type, keygen in (("weak", generate_weak_key),
                             ("standard", generate_standard_key)):
        recovered = 0
        for _ in range(TRIALS):
            n, e, d, p, q = keygen(bits)
            res = wiener_attack(e, n)
            good = is_correct_recovery(res, d, p, q)
            if good:
                # Extra end-to-end check: the recovered d really decrypts.
                m = ZZ.random_element(2, n - 1)
                good = power_mod(power_mod(m, e, n), res[0], n) == m
            recovered += int(good)
        rate = recovered / TRIALS
        print(f"{bits:>6} {key_type:>10} {TRIALS:>7} {recovered:>10} {float(rate):>7.2f}")
        rows.append(dict(bits=bits, key_type=key_type, trials=TRIALS,
                         recovered=recovered, success_rate=float(rate)))

write_csv("results/exp1_correctness.csv",
          ["bits", "key_type", "trials", "recovered", "success_rate"], rows)
