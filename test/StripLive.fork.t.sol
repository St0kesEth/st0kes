// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Test,console} from "forge-std/Test.sol";
import {Live} from "../src/Live.sol";
import {Feeds} from "../src/Feeds.sol";
import {StripEngine} from "../src/StripEngine.sol";
import {StripLive} from "../src/StripLive.sol";

contract StripLiveForkTest is Test {
    function test_64NvdaPricesOnRecordedChainInputs() public {
        vm.createSelectFork(vm.rpcUrl("hood"),67_367_297);
        StripEngine engine=new StripEngine();
        StripLive live=new StripLive(engine,Feeds.all());
        uint16[] memory bps=new uint16[](32);
        for(uint16 i;i<32;i++)bps[i]=9200+i*50;
        StripLive.Request memory q=StripLive.Request(4,bps,true,78,3,128,64,1,true);
        uint256 g=gasleft();StripLive.StripResult memory r=live.quoteStrip(q);g-=gasleft();
        assertEq(r.blockNumber,67_367_297);assertEq(r.strip.quotes.length,32);
        assertEq(r.strip.paths,128);assertEq(r.strip.independentSamples,64);
        assertEq(r.spot,222447298490000000000);assertEq(r.varStep,3154648347543);
        assertLt(g,50_000_000,"full feed-bound call must fit 50m gas");
        string memory key="strip-live-fork";
        vm.serializeUint(key,"block",r.blockNumber);vm.serializeUint(key,"blockTimestamp",block.timestamp);
        vm.serializeUint(key,"spot",r.spot);vm.serializeUint(key,"feedUpdatedAt",r.updatedAt);
        vm.serializeUint(key,"varStep",r.varStep);vm.serializeUint(key,"seed",r.seed);
        vm.serializeUint(key,"prices",64);vm.serializeUint(key,"paths",128);
        vm.serializeUint(key,"gas",g);vm.serializeUint(key,"atmCall",r.strip.quotes[16].call);
        vm.serializeUint(key,"atmSe",r.strip.quotes[16].callSe);
        string memory encoded=vm.serializeString(key,"execution","new contracts executed locally on a historical chain fork; not deployed to mainnet");
        vm.writeJson(encoded,"web/strip-live-fork.json");
        console.log("NVDA live-input 64 prices gas",g);
        console.log("NVDA ATM call / SE",r.strip.quotes[16].call,r.strip.quotes[16].callSe);
    }
}
