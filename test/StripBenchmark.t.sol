// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Test,console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";
import {EngineV2} from "../src/EngineV2.sol";
import {StripEngine} from "../src/StripEngine.sol";

contract StripBenchmark is Test {
    EngineV2 scalar; StripEngine batch;
    function setUp() public {scalar=new EngineV2();batch=new StripEngine();}
    function test_GasAndExactnessFor64Prices() public {
        uint256 v=4e12;uint256 a=0.2166e18;uint256 b=0.7293e18;
        Engine.Spec memory s=Engine.Spec(Engine.Payoff.AsianCall,100e18,100e18,v,v*(1e18-a-b)/1e18,a,b,78,3,128,1);
        uint256[] memory k=new uint256[](32);
        for(uint256 i;i<32;i++) k[i]=92e18+i*0.5e18;
        // Warm addresses consistently. The scalar baseline uses the same corrected root.
        Engine.Spec memory warm=Engine.Spec(s.payoff,s.spot,s.strike,s.var0,s.omega,s.alpha,s.beta,3,3,2,s.seed);
        scalar.quote(warm);batch.quoteStrip(warm,k,false);
        uint256 g=gasleft();StripEngine.Strip memory ordinary=batch.quoteStrip(s,k,false);uint256 ordinaryGas=g-gasleft();
        g=gasleft();StripEngine.Strip memory paired=batch.quoteStrip(s,k,true);uint256 pairedGas=g-gasleft();
        uint256 scalarGas;uint256 singleGas;
        for(uint256 i;i<32;i++) {
            s.strike=k[i];s.payoff=Engine.Payoff.AsianCall;
            g=gasleft();(uint256 c,uint256 cs)=scalar.quote(s);uint256 cg=g-gasleft();scalarGas+=cg;
            if(i==16)singleGas=cg;
            s.payoff=Engine.Payoff.AsianPut;
            g=gasleft();(uint256 p,uint256 ps)=scalar.quote(s);scalarGas+=g-gasleft();
            assertEq(ordinary.quotes[i].call,c);assertEq(ordinary.quotes[i].callSe,cs);
            assertEq(ordinary.quotes[i].put,p);assertEq(ordinary.quotes[i].putSe,ps);
        }
        console.log("scalar_64_prices_gas",scalarGas);
        console.log("unpaired_strip_gas",ordinaryGas);
        console.log("paired_strip_gas",pairedGas);
        console.log("single_atm_call_gas",singleGas);
        assertLt(pairedGas,50_000_000,"32 strikes must fit 50m execution budget");
        assertLt(ordinaryGas,scalarGas/20,"batch should remove repeated simulation");
        string memory key="strip-gas";
        vm.serializeUint(key,"strikes",32);vm.serializeUint(key,"prices",64);
        vm.serializeUint(key,"steps",78);vm.serializeUint(key,"paths",128);
        vm.serializeUint(key,"independentPairs",64);
        vm.serializeUint(key,"scalar64Gas",scalarGas);
        vm.serializeUint(key,"ordinaryStripGas",ordinaryGas);
        vm.serializeUint(key,"pairedStripGas",pairedGas);
        vm.serializeUint(key,"singleAtmCallGas",singleGas);
        vm.serializeUint(key,"ordinaryAtmCall",ordinary.quotes[16].call);
        vm.serializeUint(key,"ordinaryAtmSe",ordinary.quotes[16].callSe);
        vm.serializeUint(key,"pairedAtmCall",paired.quotes[16].call);
        string memory j=vm.serializeUint(key,"pairedAtmSe",paired.quotes[16].callSe);
        vm.writeJson(j,"web/strip-gas.json");
    }
}
