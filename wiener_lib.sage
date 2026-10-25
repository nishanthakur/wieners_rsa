# =============================================================================
# wiener_lib.sage  --  shared library for all Wiener-attack experiments
#
# Contains:
#   * d_upper_bound()          -> numeric bound for the private exponent d
#   * generate_weak_key()      -> RSA key with a deliberately small d
#   * generate_standard_key()  -> ordinary RSA key (e = 65537), used as a control
#   * wiener_attack()          -> the attack itself (integer arithmetic only)
#   * brute_force_d()          -> naive baseline: try d = 1, 2, 3, ...
#   * time_call()              -> robust timing of fast functions
#   * mean_std(), write_csv()  -> small helpers
#
# Every experiment script does   load("wiener_lib.sage")   to use these.
# =============================================================================

import csv
import os
import statistics
import time


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
def mean_std(values):
    """Return (mean, standard deviation) of a list of numbers.
    The standard deviation is 0.0 if there is only one value."""
    values = [float(v) for v in values]
    m = statistics.mean(values)
    s = statistics.stdev(values) if len(values) > 1 else 0.0
    return m, s


def write_csv(path, fieldnames, rows):
    """Write a list of dicts to a CSV file (creates the folder if needed)."""
    folder = os.path.dirname(path)
    if folder:
        os.makedirs(folder, exist_ok=True)
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print("  -> wrote", path)


def time_call(func, *args, min_time=0.05):
    """
    Return the average wall-clock time (seconds) of ONE call func(*args).

    A single call to the attack can take microseconds, which is below the clock
    resolution. We therefore repeat the call until at least `min_time` seconds
    have elapsed in total and divide by the number of repetitions.
    """
    reps = 0
    start = time.perf_counter()
    while True:
        func(*args)
        reps += 1
        elapsed = time.perf_counter() - start
        if elapsed >= min_time:
            return elapsed / reps


# -----------------------------------------------------------------------------
# Key generation
# -----------------------------------------------------------------------------
def d_upper_bound(n, d_exp=0.25, d_scale=1/3):
    """
    Return floor(d_scale * n^d_exp) as an exact Sage Integer.

    Wiener's theorem:  d < (1/3) * n^(1/4)   <=>   d_exp = 1/4, d_scale = 1/3.
    We use high-precision reals (not Python floats) so this stays correct for
    4096-bit and larger moduli.
    """
    n = Integer(n)
    R = RealField(n.nbits() + 64)
    return Integer(floor(R(d_scale) * R(n) ** R(d_exp)))


def _random_primes(bits):
    """Return primes (p, q) with q < p < 2q, each about bits/2 bits long."""
    half = Integer(bits) // 2
    q = random_prime(2 ** half - 1, lbound=2 ** (half - 1))
    p = random_prime(2 * q - 1, lbound=q + 1)   # Bertrand: a prime exists in (q, 2q)
    return p, q


def generate_weak_key(bits, d_exp=0.25, d_scale=1/3):
    """
    Generate an RSA key whose private exponent d is SMALL.

    We pick d first and then compute e = d^(-1) mod phi(n)  (the reverse of the
    normal procedure), because we need to control the size of d.

    d is drawn uniformly from [bound/2, bound] with bound = d_scale * n^d_exp.
      * default (d_exp = 1/4, d_scale = 1/3): exactly Wiener's provable bound
      * other values are used in experiment 4 to test how tight that bound is

    Returns (n, e, d, p, q) as Sage Integers.
    """
    while True:
        p, q = _random_primes(bits)
        n, phi = p * q, (p - 1) * (q - 1)
        bound = d_upper_bound(n, d_exp, d_scale)
        # d must be invertible mod phi. Try several d's before changing primes.
        for _ in range(100):
            d = ZZ.random_element(max(3, bound // 2), bound + 1)
            if gcd(d, phi) == 1:
                return n, inverse_mod(d, phi), d, p, q


def generate_standard_key(bits, e=65537):
    """
    Generate a normal RSA key (small public exponent e, hence LARGE d).
    Used as a negative control: Wiener's attack should FAIL on these keys.
    Returns (n, e, d, p, q).
    """
    while True:
        p, q = _random_primes(bits)
        phi = (p - 1) * (q - 1)
        if gcd(e, phi) == 1:
            return p * q, Integer(e), inverse_mod(e, phi), p, q


# -----------------------------------------------------------------------------
# The attack
# -----------------------------------------------------------------------------
def wiener_attack(e, n):
    """
    Wiener's attack on RSA with small private exponent.

    Idea: e*d = 1 + k*phi(n)  =>  e/n ~ k/d, so k/d is a convergent of the
    continued fraction of e/n.  For every convergent num/den we hypothesise
    k = num, d = den, and test the hypothesis:
        phi = (e*den - 1) / num          must be an integer
        p + q = n - phi + 1
        p, q are roots of  x^2 - (p+q) x + n   -> discriminant must be a
                                                   perfect square.
    If the roots multiply to n we have factored n and recovered d.

    Convergents are generated incrementally with the standard recurrence, so
    the loop stops as soon as the right one is found (early termination) and
    uses only exact integer arithmetic.

    Returns (d, p, q, tested):
        d, p, q : recovered values, or None if the attack failed
        tested  : number of convergents examined (machine-independent cost)
    """
    e, n = Integer(e), Integer(n)

    # Continued fraction of e/n via the Euclidean algorithm on (a, b) = (e, n)
    a, b = e, n
    # Convergent recurrence:  h_i = q_i*h_{i-1} + h_{i-2}   (numerators)
    #                         k_i = q_i*k_{i-1} + k_{i-2}   (denominators)
    h_prev, h = Integer(0), Integer(1)   # h_{-2}, h_{-1}
    k_prev, k = Integer(1), Integer(0)   # k_{-2}, k_{-1}
    tested = 0

    while b != 0:
        quotient = a // b                       # next partial quotient
        a, b = b, a - quotient * b              # Euclid step
        h_prev, h = h, quotient * h + h_prev    # new numerator   (candidate k)
        k_prev, k = k, quotient * k + k_prev    # new denominator (candidate d)
        tested += 1
        num, den = h, k

        # --- test the hypothesis k = num, d = den -------------------------
        if num == 0:                            # first convergent is 0/1: skip
            continue
        if (e * den - 1) % num != 0:            # phi would not be an integer
            continue
        phi = (e * den - 1) // num
        s = n - phi + 1                         # candidate for p + q
        disc = s * s - 4 * n                    # candidate for (p - q)^2
        if disc < 0:
            continue
        r = isqrt(disc)
        if r * r == disc and (s + r) % 2 == 0:
            p, q = (s + r) // 2, (s - r) // 2
            if q > 1 and p * q == n:
                return den, p, q, tested

    return None, None, None, tested             # no convergent worked


def is_correct_recovery(result, d, p, q):
    """True iff wiener_attack's result matches the real key (d and {p, q})."""
    d_rec, p_rec, q_rec, _ = result
    return d_rec is not None and d_rec == d and {p_rec, q_rec} == {p, q}


# -----------------------------------------------------------------------------
# Brute-force baseline
# -----------------------------------------------------------------------------
def brute_force_d(e, n, d_max):
    """
    Naive attack: try d = 1, 2, ..., d_max and test each candidate on two known
    messages (m = 2 and m = 3): d is accepted when (m^e)^d == m (mod n).

    To make each test cost just one modular multiplication, we keep running
    powers  t = c^d  and multiply by c once per iteration.
    Returns the recovered d (= number of candidates tried) or None.
    """
    c2, c3 = power_mod(2, e, n), power_mod(3, e, n)   # ciphertexts of 2 and 3
    t2 = t3 = Integer(1)
    for d in range(1, int(d_max) + 1):
        t2 = (t2 * c2) % n
        t3 = (t3 * c3) % n
        if t2 == 2 and t3 == 3:
            return Integer(d)
    return None
