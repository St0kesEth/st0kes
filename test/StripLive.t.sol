// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Test} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";
import {Live} from "../src/Live.sol";
import {StripEngine} from "../src/StripEngine.sol";
import {StripLive} from "../src/StripLive.sol";

contract StripMockFeed {
    function decimals() external pure returns(uint8){return 8;}
    function latestRound() external pure returns(uint256){return 100;}
    function latestRoundData() external view returns(uint80,int256,uint256,uint256,uint80){return round(100);}
    function getRoundData(uint80 id) external view returns(uint80,int256,uint256,uint256,uint80){return round(id);}
    function round(uint80 id) internal view returns(uint80,int256,uint256,uint256,uint80){
        require(id<=100 && id>0);
        uint256 ts=block.timestamp-60-(100-id)*300;
        return(id,int256(uint256(100e8+(id%2)*5e7)),ts,ts,id);
    }
}
contract StripLiveTest is Test {
    function test_OneSnapshotAllStrikesAndExplicitMetadata() public {
        vm.warp(1_789_978_299);vm.roll(68_643_786);
        StripEngine engine=new StripEngine();StripMockFeed feed=new StripMockFeed();
        Live.Feed[] memory feeds=new Live.Feed[](1);
        feeds[0]=Live.Feed(address(feed),"MOCK",266360281960,216597568381425856,729295007907443840);
        StripLive live=new StripLive(engine,feeds);
        uint16[] memory bps=new uint16[](3);bps[0]=9800;bps[1]=10000;bps[2]=10200;
        StripLive.Request memory q=StripLive.Request(0,bps,true,78,3,8,64,0,true);
        StripLive.StripResult memory r=live.quoteStrip(q);
        assertEq(r.blockNumber,block.number);assertEq(r.seed,block.number);
        assertEq(r.updatedAt,block.timestamp-60);assertEq(r.spot,100e18);
        assertEq(r.strip.quotes.length,3);assertEq(r.strip.independentSamples,4);
        uint256[] memory strikes=new uint256[](3);
        for(uint256 i;i<3;i++){strikes[i]=r.spot*bps[i]/10000;assertEq(r.strip.quotes[i].strike,strikes[i]);}
        Engine.Spec memory s=Engine.Spec(Engine.Payoff.AsianCall,r.spot,0,r.varStep,
            feeds[0].omega,feeds[0].alpha,feeds[0].beta,78,3,8,r.seed);
        StripEngine.Strip memory direct=engine.quoteStrip(s,strikes,true);
        assertEq(keccak256(abi.encode(r.strip)),keccak256(abi.encode(direct)));
    }
}
