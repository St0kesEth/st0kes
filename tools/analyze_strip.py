"""Analyze the prespecified Solidity seed study; no cherry-picked seeds or float repricing."""
import csv, hashlib, json
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
WEB=ROOT/'web'
protocol=json.loads((WEB/'strip-protocol.json').read_text())
rng=np.random.default_rng(20260921)
records=[]
for case in protocol['cases']:
    path=WEB/f"strip-study-{case['label']}.json"
    d=json.loads(path.read_text())
    assert d['replications']==protocol['replications'] and d['seedStart']==protocol['seedStart']
    n=d['replications']
    ix=rng.integers(0,n,size=(2000,n))
    for side,means,ses in [('call','Calls','CallSe'),('put','Puts','PutSe')]:
        plain=np.asarray(d['ordinary'+means],dtype=float).reshape(n,3)/1e18
        paired=np.asarray(d['paired'+means],dtype=float).reshape(n,3)/1e18
        pse=np.asarray(d['ordinary'+ses],dtype=float).reshape(n,3)/1e18
        ase=np.asarray(d['paired'+ses],dtype=float).reshape(n,3)/1e18
        for j,bps in enumerate(protocol['strikeBps']):
            p,a=plain[:,j],paired[:,j]
            vp,va=float(p.var(ddof=1)),float(a.var(ddof=1))
            ratio=vp/va if va else None
            bootp=p[ix].var(axis=1,ddof=1);boota=a[ix].var(axis=1,ddof=1)
            valid=boota>0
            ci=np.percentile(bootp[valid]/boota[valid],[2.5,97.5]).tolist() if valid.any() else [None,None]
            diff=a-p;diff_se=float(diff.std(ddof=1)/np.sqrt(n))
            rms_p=float(np.sqrt(np.mean(pse[:,j]**2)));rms_a=float(np.sqrt(np.mean(ase[:,j]**2)))
            rec=dict(case=case['label'],kind='recorded feed' if case['label'] in ['AMD','INTC','MSFT','MU','NVDA','SNDK','SPY','TSLA','USO'] else 'stress',
                payoff=side,strikeBps=bps,replications=n,ordinaryMean=float(p.mean()),pairedMean=float(a.mean()),
                ordinaryVariance=vp,pairedVariance=va,varianceRatio=ratio,varianceRatioCI95=ci,
                ordinaryGas=d['ordinaryGas'],pairedGas=d['pairedGas'],
                varianceTimesGasGain=ratio*d['ordinaryGas']/d['pairedGas'] if ratio else None,
                ordinaryReportedSeRms=rms_p,pairedReportedSeRms=rms_a,
                ordinarySpreadOverReported=float(np.sqrt(vp)/rms_p) if rms_p else None,
                pairedSpreadOverReported=float(np.sqrt(va)/rms_a) if rms_a else None,
                pairedMinusOrdinaryMean=float(diff.mean()),differenceSe=diff_se,
                meanDifferenceZ=float(diff.mean()/diff_se) if diff_se else None,
                ordinaryZeroSeCount=int((pse[:,j]==0).sum()),pairedZeroSeCount=int((ase[:,j]==0).sum()),
                sourceSha256=hashlib.sha256(path.read_bytes()).hexdigest())
            records.append(rec)
atm=[r for r in records if r['kind']=='recorded feed' and r['strikeBps']==10000 and r['payoff']=='call']
summary=dict(protocol=protocol,method='256 prespecified Solidity seed replications per case. Joint-seed bootstrap with 2000 resamples for pointwise 95% intervals. Variance-times-gas compares three-strike batches, not scalar calls. Standard errors concern sampling only. No simultaneous-coverage or market-accuracy claim.',
    recordedFeedAtmCall=dict(cases=len(atm),medianVarianceRatio=float(np.median([r['varianceRatio'] for r in atm])),
        medianVarianceTimesGasGain=float(np.median([r['varianceTimesGasGain'] for r in atm])),
        minVarianceTimesGasGain=min(r['varianceTimesGasGain'] for r in atm),maxVarianceTimesGasGain=max(r['varianceTimesGasGain'] for r in atm),
        minPairedSpreadOverReported=min(r['pairedSpreadOverReported'] for r in atm),maxPairedSpreadOverReported=max(r['pairedSpreadOverReported'] for r in atm)),
    records=records)
(WEB/'strip-study-summary.json').write_text(json.dumps(summary,indent=2,allow_nan=False)+'\n')
with (WEB/'strip-study-summary.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
print(json.dumps(summary['recordedFeedAtmCall'],indent=2))
for r in atm:
    print(r['case'],f"variance ratio {r['varianceRatio']:.3f}",f"gas-adjusted {r['varianceTimesGasGain']:.3f}",f"SE calibration {r['pairedSpreadOverReported']:.3f}")
adverse=[r for r in records if r['varianceRatio'] is not None and r['varianceRatio']<1]
print('All cases:',len(records),'same-path-count variance worsened:',len(adverse))
for r in adverse:print('ADVERSE',r['case'],r['payoff'],r['strikeBps'],r['varianceRatio'])
