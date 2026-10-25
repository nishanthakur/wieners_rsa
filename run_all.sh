#!/usr/bin/env bash
# Runs every experiment and then builds the figures.
# Usage:  ./run_all.sh           (full run)
#         ./run_all.sh --quick   (small sizes / few trials, ~1-2 minutes)
set -e
ARG="$1"
for script in exp1_correctness exp2_complexity exp3_bruteforce exp4_bound_tightness; do
    echo "=== $script ==="
    sage ${script}.sage $ARG
done
python3 plot_results.py
