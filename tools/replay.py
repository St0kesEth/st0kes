"""Replays the fork quotes off-chain, in plain Python, and checks them to the wei.

The contract walks in integer arithmetic and draws its noise from keccak, so a
quote is a pure function of the block, the seed and the arguments. This script
re-implements that arithmetic (sdiv truncates toward zero, uint division
floors) and compares its mean and standard error with web/fork.js, which
test/Live.fork.t.sol wrote from the chain at a fixed block.

    python3 tools/replay.py        # needs pysha3 or pycryptodome for keccak
"""
import json, os, sys

try:
    from Crypto.Hash import keccak
    def k256(b):
        h = keccak.new(digest_bits=256); h.update(b); return h.digest()
except ImportError:
    import sha3
    def k256(b):
        return sha3.keccak_256(b).digest()

ONE = 10 ** 18
SEED = 1  # test/Live.fork.t.sol quotes with seed 1
MASK = 0x1FFFFF  # twelve 21-bit slices of one hash, Irwin-Hall


def sdiv(a, b):
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b > 0) else -q


def normal(seed, p, t):
    h = int.from_bytes(k256(seed.to_bytes(32, "big") + ((p << 32) | t).to_bytes(32, "big")), "big")
    s = sum((h >> (21 * i)) & MASK for i in range(12))
    return sdiv((s - 6 * MASK) * ONE, 1 << 21)


def isqrt(x):
    if x == 0:
        return 0
    y, k = x, (x >> 1) + 1
    while k < y:
        y, k = k, (x // k + k) >> 1
    return y


def root(x):            # sqrt of a 1e18 fixed-point number, exact Babylonian
    return isqrt(x * ONE) if x else 0


def warm(x, guess):     # original arithmetic for the archived web/fork.js fixture
    if x == 0:
        return 0
    n, y = x * ONE, (guess or x)
    for _ in range(5):
        y = (y + n // y) >> 1
    return y


def exp_(x):            # e^x for 1e18 fixed point, Taylor on the fraction
    if x < -40 * ONE:
        return 0
    ax = -x if x < 0 else x
    n, fr = ax // ONE, ax % ONE
    term = ef = ONE
    for i in range(1, 13):
        term = term * fr // (ONE * i); ef += term
        if term == 0:
            break
    en = ONE
    for _ in range(n):
        en = en * 2718281828459045235 // ONE
    r = en * ef // ONE
    return ONE * ONE // r if x < 0 else r


def quote(f, steps, every, paths, seed):
    spot, om, al, be, v0 = f["spot"], f["omega"], f["alpha"], f["beta"], f["varStep"]
    sd0, pays = root(v0), []
    for p in range(paths):
        v, sd, logS, acc = v0, sd0, 0, 0
        for t in range(steps):
            r = sdiv(sd * normal(seed, p, t), ONE)
            logS += r - v // 2
            v = om + al * sdiv(r * r, ONE) // ONE + be * v // ONE
            sd = warm(v, sd)
            if (t + 1) % every == 0:
                acc += exp_(logS)
        avg = spot * (acc // (steps // every)) // ONE
        pays.append(avg - spot if avg > spot else 0)
    n = paths
    mean, e2 = sum(pays) // n, sum(x * x for x in pays) // n
    var = (e2 - mean * mean) * n // (n - 1) if e2 > mean * mean else 0
    return mean, isqrt(var // n)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    s = open(os.path.join(here, "..", "web", "fork.js")).read()
    d = json.loads(s[s.index("{"):])
    print(f"block {d['block']}, seed {SEED}, {d['paths']} paths, {d['steps']} steps")
    ok = True
    for f in d["feeds"]:
        mean, se = quote(f, d["steps"], d["every"], d["paths"], SEED)
        hit = (mean, se) == (f["asianCall"], f["se"])
        ok &= hit
        print(f"{f['symbol']:>5}  python {mean} +- {se}\n       chain  {f['asianCall']} +- {f['se']}  {'MATCH' if hit else 'MISMATCH'}")
    print("all nine match to the wei" if ok else "MISMATCH")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
