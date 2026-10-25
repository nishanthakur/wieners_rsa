# Wiener's attack – experiments

## Requirements
* SageMath (any recent version) to run the `.sage` files
* Python 3 with `numpy` and `matplotlib` for `plot_results.py`

## Run
Run everything from inside this folder (the scripts `load()` the library by relative path).

```bash
./run_all.sh --quick     # smoke test, ~1-2 min
./run_all.sh             # full run
# or individually:
sage exp1_correctness.sage
sage exp2_complexity.sage          # add --big for 8192-bit keys
sage exp3_bruteforce.sage
sage exp4_bound_tightness.sage
python3 plot_results.py
```

## Files
| File | Purpose | Output |
|---|---|---|
| `wiener_lib.sage` | key generation, the attack, brute-force baseline, timing helpers | – |
| `exp1_correctness.sage` | success rate on weak keys + negative control on standard keys | `results/exp1_correctness.csv` |
| `exp2_complexity.sage` | convergents and time vs. key size | `results/exp2_complexity_*.csv` |
| `exp3_bruteforce.sage` | Wiener vs. exhaustive search over d | `results/exp3_bruteforce.csv` |
| `exp4_bound_tightness.sage` | success rate as d grows past n^(1/4)/3 | `results/exp4_bound_*.csv` |
| `plot_results.py` | figures | `figures/fig1..fig3` (PNG + PDF) |

## Mapping to the report
* Table: copy the markdown table printed by `exp2` (also in `exp2_complexity_summary.csv`).
* Fig. 1 → complexity vs. your O(log n)·cost-of-arithmetic analysis.
* Fig. 2 → exponential (brute force) vs. polynomial (Wiener).
* Fig. 3 → where the theorem's condition comes from.
* Exp. 1 → one sentence: "100% recovery on N weak keys, 0% on standard keys".

## Reproducibility
Each experiment sets a fixed seed (`set_random_seed`). Report your Sage version, CPU,
and the number of trials (top of each script) in the setup paragraph.
