"""Render the measured accuracy/cost result and write its research note."""
import json
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'research';OUT.mkdir(exist_ok=True)
g=json.loads((ROOT/'web/strip-gas.json').read_text())
s=json.loads((ROOT/'web/strip-study-summary.json').read_text())
f=json.loads((ROOT/'web/strip-live-fork.json').read_text())
atm=[r for r in s['records'] if r['kind']=='recorded feed' and r['payoff']=='call' and r['strikeBps']==10000]
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,'text.parse_math':False})
paper='#f5f2e9';ink='#1c2422';green='#276951';muted='#68706a'
fig=plt.figure(figsize=(15,8.8),facecolor=paper)
fig.text(.055,.93,'St0kes / Shared-path option pricing',fontsize=14,color=muted)
fig.text(.055,.855,'64 option prices. Less gas than one.',fontsize=29,color=ink,weight='bold')
fig.text(.055,.80,'Reference benchmark: 128 physical paths, 78 steps, 26 averaging observations, 32 strikes.',fontsize=11,color=muted)
ax=fig.add_axes([.23,.27,.28,.43],facecolor=paper)
names=['64 separate prices','64 shared-path prices','64 paired prices','1 separate ATM call']
vals=[g['scalar64Gas']/1e6,g['ordinaryStripGas']/1e6,g['pairedStripGas']/1e6,g['singleAtmCallGas']/1e6]
ax.barh(np.arange(4),vals,color=['#8b9691','#597a6d',green,'#b0b4aa'],height=.52)
ax.set_yticks(np.arange(4),names);ax.invert_yaxis();ax.set_xscale('log');ax.set_xlim(10,5000)
ax.set_xlabel('Execution gas, millions (log scale)',color=muted)
ax.set_xticks([10,100,1000],[10,100,1000]);ax.grid(axis='x',alpha=.15);ax.set_axisbelow(True)
for i,v in enumerate(vals):ax.text(v*1.08,i,f'{v:,.2f}M',va='center',fontsize=11,color=ink)
for spine in ax.spines.values():spine.set_visible(False)
ax.tick_params(axis='y',length=0,pad=10)
fig.text(.055,.731,'Measured Solidity execution cost',fontsize=12,color=ink)
bx=fig.add_axes([.625,.27,.31,.43],facecolor=paper)
for i,r in enumerate(atm):
    gain=r['varianceTimesGasGain'];mult=r['ordinaryGas']/r['pairedGas'];lo,hi=np.array(r['varianceRatioCI95'])*mult
    bx.errorbar(gain,i,xerr=[[gain-lo],[hi-gain]],fmt='o',color=green,capsize=3,markersize=5)
bx.set_yticks(range(9),[r['case'] for r in atm]);bx.invert_yaxis();bx.axvline(1,color=muted,linestyle=':')
bx.set_xlim(.7,3.6);bx.set_xlabel('Variance × gas improvement factor',color=muted)
bx.set_title('ATM calls / 256 seeds per asset',loc='left',pad=18,color=ink)
for spine in bx.spines.values():spine.set_visible(False)
bx.tick_params(axis='y',length=0);bx.grid(axis='x',alpha=.15)
fig.text(.055,.17,f"{g['scalar64Gas']/g['pairedStripGas']:.1f}× lower gas than 64 separate calls. Unpaired batching matches all scalar price/SE outputs exactly.",fontsize=12,color=ink)
fig.text(.055,.125,'Error bars: pointwise 95% joint-seed bootstrap intervals. Efficiency panel measures three-strike batches.',fontsize=10,color=muted)
fig.text(.055,.09,'Sampling precision only. Four of 78 payoff/strike cases had higher empirical variance with pairing. No universal gain claimed.',fontsize=10,color=muted)
fig.text(.055,.055,'Local prototype and historical-fork verification. New contracts are not deployed. Baselines share the exact-root fix.',fontsize=10,color=muted)
fig.savefig(OUT/'strip-results.png',dpi=150,facecolor=paper)
fig.savefig(OUT/'strip-results.svg',facecolor=paper)
plt.close(fig)

adverse=[r for r in s['records'] if r['varianceRatio'] is not None and r['varianceRatio']<1]
rows='\n'.join(f"| {r['case']} | {r['varianceRatio']:.3f} | {r['varianceRatioCI95'][0]:.3f}–{r['varianceRatioCI95'][1]:.3f} | {r['varianceTimesGasGain']:.3f} | {r['pairedSpreadOverReported']:.3f} |" for r in atm)
bad='\n'.join(f"- {r['case']} {r['payoff']}, strike {r['strikeBps']/100:.0f}% of spot: variance ratio {r['varianceRatio']:.3f}." for r in adverse)
note=f'''# Shared-path option strips under an EVM computation budget

## Result

A 32-strike strip (32 calls and 32 puts) runs in **{g['pairedStripGas']:,} gas** in the paired
reference benchmark. A single scalar ATM Asian call costs **{g['singleAtmCallGas']:,} gas** under
the same model configuration and exact-root correction. Computing all 64 prices separately costs
**{g['scalar64Gas']:,} gas**. The paired strip is {g['scalar64Gas']/g['pairedStripGas']:.2f} times cheaper than that
64-call baseline, and costs {100*(1-g['pairedStripGas']/g['singleAtmCallGas']):.2f}% less than one scalar ATM call.

The intermediate unpaired strip costs **{g['ordinaryStripGas']:,} gas** and matches every scalar
call, put and standard error to the integer unit. Pairing changes the finite sampled paths;
its output is not claimed to be bit-identical to the unpaired estimator.

These are measured execution costs, not fees paid, universal protocol rankings, or production price guarantees.
The baseline is this repository's scalar engine, not a best-in-class survey of competing implementations.

## Why it works

The expensive part is generating a path-dependent underlying value. Once each terminal value
or arithmetic observation average A_i exists, all requested strikes reuse it:

    call(K) = mean(max(A_i - K, 0))
    put(K)  = mean(max(K - A_i, 0))

This removes repeated path generation across strikes and option sides. It also couples the
sampling noise across the strip: the same sampled distribution determines every quote.

The GARCH recursion depends on a shock through its square:

    v_next = omega + alpha * r² + beta * v

Negating every shock leaves its variance path unchanged. The antithetic implementation computes
hashes, variances and square roots once, while accumulating two signed price paths. Observation
exponentials and payoffs are still computed where each branch requires them.

Antithetic variates and shared simulations are established techniques. This work's contribution
is the implemented cost/precision study and auditable EVM integration, not a new Monte Carlo theorem
or a solution of a Navier–Stokes problem. Prior work: Boyle, Broadie and Glasserman,
[Monte Carlo methods for security pricing](https://business.columbia.edu/faculty/research/monte-carlo-methods-security-pricing-0).

## Correct standard errors

A mirrored pair is one independent sampling unit. With n independent pairs and Q_i = C_i+ + C_i−:

    estimate = mean(Q) / 2
    SE       = sqrt(sample_variance(Q) / n) / 2

The implementation estimates pair moments directly. It does not count the two dependent paths
as independent observations. Prices and SEs use the engine's integer arithmetic and rounding.

## Prespecified experiment

- Nine saved feed parameter profiles at block 67,367,297; four additional regimes: constant variance,
  high persistence, higher initial volatility and a zero initial variance followed by positive omega.
- 256 consecutive held-out seeds, 10000–10255; all seeds are retained. No parameter fitting on these seeds.
- 128 physical paths per quote: 128 independent paths or 64 independent mirrored pairs.
- 78 simulation steps; every third step contributes to the 26-observation arithmetic average.
- Strikes at 98%, 100% and 102% of spot; both calls and puts: 78 profile/payoff/strike cases.
- Every estimate and SE is produced by Solidity. Python only analyzes the exported results.
- Pointwise 95% intervals bootstrap the paired seed rows jointly, with 2000 resamples.
- The same seeds are reused across profiles; the nine profiles are not independent market experiments.
- Cost-adjusted efficiency is variance_plain * gas_plain / (variance_pair * gas_pair), measured for
  the same three-strike batches, using mean gas across all 256 seeds. The intervals resample
  seed outcomes jointly and hold those mean gas measurements fixed. It is not a directly measured
  universal fixed-budget RMSE ratio.

## Recorded-feed ATM call results

| Profile | Variance reduction factor | Pointwise 95% interval | Variance × gas gain | Observed spread / reported SE RMS |
|---|---:|---:|---:|---:|
{rows}

The median variance-times-gas improvement is **{s['recordedFeedAtmCall']['medianVarianceTimesGasGain']:.3f}×**.
The ratio of observed replication spread to RMS reported paired SE ranges from
{s['recordedFeedAtmCall']['minPairedSpreadOverReported']:.3f} to {s['recordedFeedAtmCall']['maxPairedSpreadOverReported']:.3f}
for these ATM calls. This checks sampling error calibration in these cases; it does not validate
the pricing measure, future market prices, tails, or model adequacy.

## Negative and limited results

Four of 78 cases have a higher empirical variance at equal physical path count with pairing:

{bad}

These are retained in the data and report. Pairing does not guarantee lower variance for every payoff.
Sparse out-of-the-money payoffs can produce zero estimated SE in a finite sample even when true
uncertainty is nonzero; raw zero-SE counts are included in the summary. No exact option-price
confidence interval or absence-of-tail-risk claim is made.

## Arithmetic safety and consistency

The old five-pass warm root returned 31,292,613,410,496,640 for x=4e12 with a zero starting guess,
instead of the exact fixed-point root 2,000,000,000,000,000. The engine now uses an exact fallback
for zero guesses and continues Newton iteration until integer convergence for other guesses.
The averaging step is overflow-safe. Both performance baselines use this same fix.

Tests cover the known counterexample, 256 fuzzed root inputs/guesses, mirrored paths against
independently advanced branches, pair-aware standard errors, scalar/strip equality, sorted-strike
validation, monotonicity, bounded vertical spreads and sample put-call parity. Convexity and parity
checks explicitly allow at most two/one integer units, respectively, for quote rounding. Parity is
against the sample underlying mean, not an unsupported claim that it equals spot exactly.

Correcting the root can change old outputs by tiny integer amounts. The old web/fork.js fixture
and tools/replay.py are preserved as historical artifacts. tools/replay_strip.py checks the new
implementation with Python's independent math.isqrt: **312 price/SE outputs and 26 underlying means
match exactly** across all 13 replay profiles.

## Feed-bound execution

StripLive reads spot and cadence once, constructs relative strikes from that same spot, and returns
block number, seed, feed timestamp and initial variance with the strip. A historical-chain fork test
for NVDA at block **{f['block']:,}** produced all 64 prices in **{f['gas']:,} gas**, including feed access,
below the tested 50-million computation budget. The feed timestamp is **{f['feedUpdatedAt']}**;
the fork block timestamp is **{f['blockTimestamp']}**. These are historical inputs, not a current price feed.

New contracts were deployed only inside the local fork for this test. No mainnet deployment or
transaction was made. Existing deployed addresses and the website design remain unchanged.

## Reproduce

Requires Foundry with solc 0.8.26. Python replay requires pycryptodome or pysha3; analysis requires numpy.
Charts additionally require matplotlib. Run from the repository root:

```sh
forge test --match-contract 'Strip(EngineTest|Benchmark|Study|LiveTest|ReplayTest)' --fuzz-runs 256 -vv
python3 tools/analyze_strip.py
python3 tools/replay_strip.py
forge test --match-contract StripLiveForkTest -vv
python3 tools/report_strip.py
```

The last Solidity test requires historical-state RPC access. The rest of the new tests are local.
Original EngineTest and AuditTest also passed after the arithmetic fix. In total, 31 distinct tests
passed, in addition to the 256 root fuzz examples and exact Python replay. Runtime bytecode is below
the EIP-170 size limit for all new contracts.

Machine-readable inputs/results: ../web/strip-protocol.json, ../web/strip-gas.json,
../web/strip-study-*.json, ../web/strip-study-summary.csv, ../web/strip-replay-*.json and
../web/strip-live-fork.json. The raw negative results are included.

## Remaining scope

The sampler remains a bounded twelve-uniform approximation to a Gaussian. Its Gaussian drift
correction is not an exact martingale correction for all accepted variances. Fitted historical GARCH
parameters and a reproducible estimator do not establish a market risk-neutral measure. This work
improves computation and sampling efficiency under the specified model; it does not certify fair
market value, trade readiness, or universal numerical accuracy throughout arbitrary uint256 inputs.
'''
(OUT/'strip-study.md').write_text(note)
print('Wrote research/strip-study.md, strip-results.png and strip-results.svg')
