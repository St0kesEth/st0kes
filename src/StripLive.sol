// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Engine} from "./Engine.sol";
import {Live} from "./Live.sol";
import {StripEngine} from "./StripEngine.sol";

/// One feed snapshot, one cadence estimate, one path set, a full strike strip.
/// Returned timestamps identify the input's age; they do not certify freshness.
contract StripLive is Live {
    struct Request {
        uint256 feed;
        uint16[] strikeBps; // relative to the same spot read inside this call
        bool asian;
        uint16 steps;
        uint16 every;
        uint16 paths;
        uint256 rounds;
        uint256 seed;     // zero selects the current block number
        bool paired;
    }
    struct StripResult {
        StripEngine.Strip strip;
        uint256 spot;
        uint256 updatedAt;
        uint256 varStep;
        uint256 seed;
        uint256 blockNumber;
    }
    constructor(StripEngine e, Feed[] memory f) Live(Engine(address(e)), f) {}

    function quoteStrip(Request memory q) external view returns(StripResult memory r) {
        (r.spot,r.updatedAt)=spot(q.feed);
        (r.varStep,,,)=cadence(q.feed,q.rounds);
        r.seed=q.seed==0?block.number:q.seed;
        r.blockNumber=block.number;
        uint256[] memory strikes=new uint256[](q.strikeBps.length);
        for(uint256 i;i<strikes.length;i++) strikes[i]=r.spot*q.strikeBps[i]/10000;
        Feed memory f=feeds_[q.feed];
        Engine.Spec memory s=Engine.Spec(q.asian?Engine.Payoff.AsianCall:Engine.Payoff.Call,
            r.spot,0,r.varStep,f.omega,f.alpha,f.beta,q.steps,q.every,q.paths,r.seed);
        r.strip=StripEngine(address(engine)).quoteStrip(s,strikes,q.paired);
    }
}
