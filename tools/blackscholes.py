"""Black-Scholes call prices at zero rate for the Brownian check in test/Engine.t.sol.
Spot 100, variance 4e-6 per step, 78 steps."""
import json, math, os
def N(x): return 0.5 * (1 + math.erf(x / math.sqrt(2)))
S, var_step, steps = 100.0, 4e-6, 78
sig = math.sqrt(var_step * steps)
def call(K):
    d1 = (math.log(S / K) + sig * sig / 2) / sig
    return S * N(d1) - K * N(d1 - sig)
ref = {"spot": int(S * 1e18), "varStep": int(var_step * 1e18), "steps": steps,
       "call100": int(round(call(100) * 1e18)), "call102": int(round(call(102) * 1e18)), "put98": int(round((call(98) - (S - 98)) * 1e18))}
here = os.path.dirname(os.path.abspath(__file__))
json.dump(ref, open(os.path.join(here, "..", "data", "reference.json"), "w"), indent=1)
print({k: (v / 1e18 if k != "steps" else v) for k, v in ref.items()})
