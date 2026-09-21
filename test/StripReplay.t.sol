// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Test} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";
import {StripEngine} from "../src/StripEngine.sol";

contract StripReplayTest is Test {
    function test_ExportIndependentReplayFixtures() public {
        StripEngine e=new StripEngine();
        string memory data=vm.readFile("web/strip-protocol.json");
        for(uint256 i;i<13;i++) {
            string memory base=string.concat(".cases[",vm.toString(i),"]");
            string memory label=vm.parseJsonString(data,string.concat(base,".label"));
            Engine.Spec memory s=Engine.Spec(Engine.Payoff.AsianCall,v(data,base,"spot"),0,v(data,base,"var0"),
                v(data,base,"omega"),v(data,base,"alpha"),v(data,base,"beta"),78,3,128,1);
            uint256[] memory k=new uint256[](3);k[0]=s.spot*9800/10000;k[1]=s.spot;k[2]=s.spot*10200/10000;
            StripEngine.Strip memory plain=e.quoteStrip(s,k,false);
            StripEngine.Strip memory paired=e.quoteStrip(s,k,true);
            uint256[] memory expected=new uint256[](30);
            for(uint256 j;j<3;j++) {
                expected[j*5]=k[j];expected[j*5+1]=plain.quotes[j].call;expected[j*5+2]=plain.quotes[j].put;
                expected[j*5+3]=plain.quotes[j].callSe;expected[j*5+4]=plain.quotes[j].putSe;
                expected[15+j*5]=k[j];expected[16+j*5]=paired.quotes[j].call;expected[17+j*5]=paired.quotes[j].put;
                expected[18+j*5]=paired.quotes[j].callSe;expected[19+j*5]=paired.quotes[j].putSe;
            }
            vm.serializeString(label,"label",label);vm.serializeUint(label,"seed",1);
            vm.serializeUint(label,"ordinaryUnderlyingMean",plain.underlyingMean);
            vm.serializeUint(label,"pairedUnderlyingMean",paired.underlyingMean);
            string memory encoded=vm.serializeUint(label,"quotes",expected);
            vm.writeJson(encoded,string.concat("web/strip-replay-",label,".json"));
        }
    }
    function v(string memory d,string memory b,string memory field) internal pure returns(uint256) {
        return vm.parseJsonUint(d,string.concat(b,".",field));
    }
}
