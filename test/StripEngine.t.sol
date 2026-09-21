// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";
import {StripEngine} from "../src/StripEngine.sol";

contract StripHarness is StripEngine {
    function warm(uint256 x,uint256 guess) external pure returns(uint256) {return warmRoot(x,guess);}
    function cold(uint256 x) external pure returns(uint256) {return root(x);}
    function pair(Engine.Spec memory s,uint256 p) external pure returns(uint256,uint256) {return pairValues(s,p,root(s.var0));}
    function naiveValue(Engine.Spec memory s,uint256 p,bool negative) external pure returns(uint256) {
        bool asian=uint8(s.payoff)>=2;
        uint256 v=s.var0; uint256 sd=root(v); int256 logS; uint256 acc;
        for(uint256 t;t<s.steps;t++) {
            int256 z=normal(s.seed,p,t); if(negative) z=-z;
            int256 r=int256(sd)*z/int256(ONE);
            logS+=r-int256(v/2);
            v=s.omega+s.alpha*uint256(r*r/int256(ONE))/ONE+s.beta*v/ONE;
            sd=warmRoot(v,sd);
            if(asian && (t+1)%s.every==0) acc+=exp(logS);
        }
        return asian?s.spot*(acc/(s.steps/s.every))/ONE:s.spot*exp(logS)/ONE;
    }
}

contract StripEngineTest is Test {
    StripHarness e;
    function setUp() public {e=new StripHarness();}
    function spec(Engine.Payoff p,uint16 paths,uint256 seed) internal pure returns(Engine.Spec memory) {
        uint256 v=4e12; uint256 a=0.2166e18; uint256 b=0.7293e18;
        return Engine.Spec(p,100e18,100e18,v,v*(1e18-a-b)/1e18,a,b,78,3,paths,seed);
    }
    function strikes(uint256 n) internal pure returns(uint256[] memory k) {
        k=new uint256[](n);for(uint256 i;i<n;i++) k[i]=92e18+i*0.5e18;
    }
    function test_ZeroGuessRegression() public view {
        assertEq(e.warm(4e12,0),2e15);
        assertEq(e.warm(4e12,1),2e15);
        assertEq(e.warm(0,1),0);
        Engine.Spec memory s=spec(Engine.Payoff.AsianCall,4,1);
        s.var0=0;s.omega=4e12;
        (uint256 a,uint256 b)=e.pair(s,0);
        assertEq(a,e.naiveValue(s,0,false));assertEq(b,e.naiveValue(s,0,true));
    }
    function testFuzz_WarmRootIsExact(uint256 x,uint256 guess) public view {
        x=bound(x,0,type(uint256).max/1e18);
        uint256 y=e.warm(x,guess);uint256 n=x*1e18;
        assertEq(y,e.cold(x));
        if(y!=0) assertLe(y,n/y);
        assertGt(y+1,n/(y+1));
    }
    function test_SharedVariancePairEqualsIndependentWalks() public view {
        for(uint256 mode;mode<2;mode++) {
            Engine.Spec memory s=spec(mode==0?Engine.Payoff.Call:Engine.Payoff.AsianCall,8,71);
            for(uint256 p;p<4;p++) {
                (uint256 a,uint256 b)=e.pair(s,p);
                assertEq(a,e.naiveValue(s,p,false));
                assertEq(b,e.naiveValue(s,p,true));
            }
        }
    }
    function test_UnpairedStripMatchesScalarToTheWei() public view {
        uint256[] memory k=new uint256[](5);k[0]=0;k[1]=98e18;k[2]=100e18;k[3]=102e18;k[4]=200e18;
        for(uint256 mode;mode<2;mode++) {
            Engine.Spec memory s=spec(mode==0?Engine.Payoff.Call:Engine.Payoff.AsianCall,8,47);
            StripEngine.Strip memory strip=e.quoteStrip(s,k,false);
            assertEq(strip.paths,8);assertEq(strip.independentSamples,8);
            for(uint256 j;j<k.length;j++) {
                s.strike=k[j];s.payoff=mode==0?Engine.Payoff.Call:Engine.Payoff.AsianCall;
                (uint256 c,uint256 cs)=e.quote(s);
                s.payoff=mode==0?Engine.Payoff.Put:Engine.Payoff.AsianPut;
                (uint256 p,uint256 ps)=e.quote(s);
                assertEq(strip.quotes[j].call,c);assertEq(strip.quotes[j].callSe,cs);
                assertEq(strip.quotes[j].put,p);assertEq(strip.quotes[j].putSe,ps);
            }
        }
    }
    function test_PairStandardErrorUsesPairMeans() public view {
        Engine.Spec memory s=spec(Engine.Payoff.AsianCall,8,101);
        uint256[] memory k=new uint256[](1);k[0]=100e18;
        StripEngine.Strip memory strip=e.quoteStrip(s,k,true);
        uint256 sum;uint256 sq;
        for(uint256 i;i<4;i++) {
            uint256 a=e.naiveValue(s,i,false);uint256 b=e.naiveValue(s,i,true);
            uint256 pay=(a>100e18?a-100e18:0)+(b>100e18?b-100e18:0);
            sum+=pay;sq+=pay*pay;
        }
        uint256 mean=sum/4;
        uint256 variance=(sq/4-mean*mean)*4/3;
        assertEq(strip.independentSamples,4);
        assertEq(strip.quotes[0].call,sum/8);
        assertEq(strip.quotes[0].callSe,sqrt(variance/4)/2);
    }
    function test_StripShapeAndSampleParity() public view {
        uint256[] memory k=strikes(32);
        for(uint256 mode;mode<2;mode++) {
            Engine.Spec memory s=spec(Engine.Payoff.AsianCall,32,703);
            StripEngine.Strip memory q=e.quoteStrip(s,k,mode==1);
            for(uint256 i;i<k.length;i++) {
                int256 parity=int256(q.quotes[i].call)-int256(q.quotes[i].put);
                assertApproxEqAbs(parity,int256(q.underlyingMean)-int256(k[i]),1);
                if(i>0) {
                    assertGe(q.quotes[i-1].call,q.quotes[i].call);
                    assertLe(q.quotes[i-1].put,q.quotes[i].put);
                    assertLe(q.quotes[i-1].call-q.quotes[i].call,k[i]-k[i-1]);
                    assertLe(q.quotes[i].put-q.quotes[i-1].put,k[i]-k[i-1]);
                }
                if(i>0 && i+1<k.length) {
                    // Flooring to one integer unit can contribute at most two units.
                    assertGe(q.quotes[i-1].call+q.quotes[i+1].call+2,2*q.quotes[i].call);
                    assertGe(q.quotes[i-1].put+q.quotes[i+1].put+2,2*q.quotes[i].put);
                }
            }
        }
    }
    function test_RejectsInvalidStrip() public {
        Engine.Spec memory s=spec(Engine.Payoff.AsianCall,8,1);
        vm.expectRevert(StripEngine.BadStrikes.selector);e.quoteStrip(s,new uint256[](0),false);
        uint256[] memory k=strikes(33);
        vm.expectRevert(StripEngine.BadStrikes.selector);e.quoteStrip(s,k,false);
        k=strikes(2);k[1]=k[0];
        vm.expectRevert(StripEngine.BadStrikes.selector);e.quoteStrip(s,k,false);
        k=strikes(1);s.paths=3;
        vm.expectRevert(StripEngine.BadPairCount.selector);e.quoteStrip(s,k,true);
        s.paths=2;
        vm.expectRevert(StripEngine.BadPairCount.selector);e.quoteStrip(s,k,true);
        s.paths=8;s.every=5;
        vm.expectRevert(Engine.BadSpec.selector);e.quoteStrip(s,k,false);
    }
    function sqrt(uint256 n) internal pure returns(uint256 y) {
        if(n==0)return 0;y=n;uint256 k=(n>>1)+1;
        while(k<y){y=k;k=(n/k+k)>>1;}
    }
}
