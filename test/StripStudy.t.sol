// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Test,console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";
import {StripEngine} from "../src/StripEngine.sol";

/// Prespecified, held-out seeds. Every reported observation is an actual
/// Solidity execution, including its integer arithmetic and pair-aware SE.
contract StripStudy is Test {
    StripEngine e;
    uint256 constant R=256;
    uint256 constant START=10000;
    struct Series {
        uint256[] ordinaryCalls;uint256[] ordinaryCallSe;
        uint256[] pairedCalls;uint256[] pairedCallSe;
        uint256[] ordinaryPuts;uint256[] ordinaryPutSe;
        uint256[] pairedPuts;uint256[] pairedPutSe;
    }
    function setUp() public {e=new StripEngine();}
    function test_AMD() public {runCase(0);}
    function test_INTC() public {runCase(1);}
    function test_MSFT() public {runCase(2);}
    function test_MU() public {runCase(3);}
    function test_NVDA() public {runCase(4);}
    function test_SNDK() public {runCase(5);}
    function test_SPY() public {runCase(6);}
    function test_TSLA() public {runCase(7);}
    function test_USO() public {runCase(8);}
    function test_CONSTANT() public {runCase(9);}
    function test_PERSISTENT() public {runCase(10);}
    function test_HIGH_VOL() public {runCase(11);}
    function test_ZERO_START() public {runCase(12);}
    function value(string memory data,string memory base,string memory field) internal pure returns(uint256) {
        return vm.parseJsonUint(data,string.concat(base,".",field));
    }
    function runCase(uint256 index) internal {
        string memory data=vm.readFile("web/strip-protocol.json");
        string memory base=string.concat(".cases[",vm.toString(index),"]");
        string memory label=vm.parseJsonString(data,string.concat(base,".label"));
        Engine.Spec memory s=Engine.Spec(Engine.Payoff.AsianCall,
            value(data,base,"spot"),0,value(data,base,"var0"),value(data,base,"omega"),
            value(data,base,"alpha"),value(data,base,"beta"),78,3,128,START);
        uint256[] memory k=new uint256[](3);
        k[0]=s.spot*9800/10000;k[1]=s.spot;k[2]=s.spot*10200/10000;
        uint256 count=R*3;
        Series memory a=Series(new uint256[](count),new uint256[](count),new uint256[](count),new uint256[](count),
            new uint256[](count),new uint256[](count),new uint256[](count),new uint256[](count));
        uint256 plainGas;uint256 pairedGas;
        uint256[] memory ordinaryGasBySeed=new uint256[](R);
        uint256[] memory pairedGasBySeed=new uint256[](R);
        for(uint256 i;i<R;i++) {
            s.seed=START+i;
            uint256 g=gasleft();StripEngine.Strip memory plain=e.quoteStrip(s,k,false);uint256 pg=g-gasleft();
            g=gasleft();StripEngine.Strip memory paired=e.quoteStrip(s,k,true);uint256 ag=g-gasleft();
            ordinaryGasBySeed[i]=pg;pairedGasBySeed[i]=ag;
            plainGas+=pg;pairedGas+=ag;
            assertEq(paired.independentSamples,64);assertEq(plain.independentSamples,128);
            for(uint256 j;j<3;j++) {
                uint256 z=i*3+j;
                a.ordinaryCalls[z]=plain.quotes[j].call;a.ordinaryCallSe[z]=plain.quotes[j].callSe;
                a.pairedCalls[z]=paired.quotes[j].call;a.pairedCallSe[z]=paired.quotes[j].callSe;
                a.ordinaryPuts[z]=plain.quotes[j].put;a.ordinaryPutSe[z]=plain.quotes[j].putSe;
                a.pairedPuts[z]=paired.quotes[j].put;a.pairedPutSe[z]=paired.quotes[j].putSe;
            }
        }
        vm.serializeString(label,"label",label);vm.serializeUint(label,"replications",R);
        vm.serializeUint(label,"seedStart",START);vm.serializeUint(label,"paths",128);
        vm.serializeUint(label,"steps",78);vm.serializeUint(label,"strikes",k);
        vm.serializeUint(label,"ordinaryGas",plainGas/R);vm.serializeUint(label,"pairedGas",pairedGas/R);
        vm.serializeUint(label,"ordinaryGasBySeed",ordinaryGasBySeed);
        vm.serializeUint(label,"pairedGasBySeed",pairedGasBySeed);
        vm.serializeUint(label,"ordinaryCalls",a.ordinaryCalls);vm.serializeUint(label,"ordinaryCallSe",a.ordinaryCallSe);
        vm.serializeUint(label,"pairedCalls",a.pairedCalls);vm.serializeUint(label,"pairedCallSe",a.pairedCallSe);
        vm.serializeUint(label,"ordinaryPuts",a.ordinaryPuts);vm.serializeUint(label,"ordinaryPutSe",a.ordinaryPutSe);
        vm.serializeUint(label,"pairedPuts",a.pairedPuts);
        string memory encoded=vm.serializeUint(label,"pairedPutSe",a.pairedPutSe);
        vm.writeJson(encoded,string.concat("web/strip-study-",label,".json"));
        console.log(label,"completed seeds",R);
    }
}
