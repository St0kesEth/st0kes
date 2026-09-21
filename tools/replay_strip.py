"""Independently replay current strip arithmetic, using Python's exact isqrt.

Checks 13 parameter profiles, 3 strikes, ordinary and paired calls/puts/SE.
The legacy replay.py continues to reproduce the original archived fork fixture.
"""
import json, math
from pathlib import Path
from replay import normal, exp_, sdiv

ONE=10**18
ROOT=Path(__file__).resolve().parents[1]

def values(c,seed,paths=128,steps=78,every=3):
    plus=[];minus=[]
    for p in range(paths):
        v=c['var0'];sd=math.isqrt(v*ONE);la=lb=aa=ab=0
        for t in range(steps):
            r=sdiv(sd*normal(seed,p,t),ONE)
            la+=r-v//2;lb+=-r-v//2
            v=c['omega']+c['alpha']*(r*r//ONE)//ONE+c['beta']*v//ONE
            sd=math.isqrt(v*ONE)
            if (t+1)%every==0:
                aa+=exp_(la)
                if p<paths//2:ab+=exp_(lb)
        plus.append(c['spot']*(aa//(steps//every))//ONE)
        if p<paths//2:minus.append(c['spot']*(ab//(steps//every))//ONE)
    return plus,minus

def moments(unit_sums,width):
    n=len(unit_sums);total=sum(unit_sums);m=total//n
    e2=sum(x*x for x in unit_sums)//n
    variance=(e2-m*m)*n//(n-1) if e2>m*m else 0
    return total//(n*width),math.isqrt(variance//n)//width

def main():
    protocol=json.loads((ROOT/'web/strip-protocol.json').read_text())
    comparisons=0
    for c in protocol['cases']:
        expected=json.loads((ROOT/f"web/strip-replay-{c['label']}.json").read_text())
        p,m=values(c,expected['seed'])
        assert sum(p)//len(p)==int(expected['ordinaryUnderlyingMean'])
        assert (sum(p[:len(m)])+sum(m))//(2*len(m))==int(expected['pairedUnderlyingMean'])
        actual=[]
        for paired in (False,True):
            for bps in protocol['strikeBps']:
                k=c['spot']*bps//10000
                if paired:
                    calls=[max(a-k,0)+max(b-k,0) for a,b in zip(p,m)]
                    puts=[max(k-a,0)+max(k-b,0) for a,b in zip(p,m)]
                else:
                    calls=[max(a-k,0) for a in p];puts=[max(k-a,0) for a in p]
                call,cs=moments(calls,2 if paired else 1)
                put,ps=moments(puts,2 if paired else 1)
                actual.extend([k,call,put,cs,ps])
        assert actual==[int(x) for x in expected['quotes']],c['label']
        comparisons+=24
        print(c['label'],'ordinary + paired prices and standard errors: EXACT MATCH')
    print(f'{comparisons} price/SE outputs and 26 underlying means matched exactly.')

if __name__=='__main__':main()
