// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Live} from "../src/Live.sol";
import {StripEngine} from "../src/StripEngine.sol";
import {StripLive} from "../src/StripLive.sol";
import {Feeds} from "../src/Feeds.sol";
import {SpaceX} from "../src/SpaceX.sol";

/// The SpaceX strip on the live chain: the feed publishes on movement like the
/// other nine, so the cadence variance and the strip work unchanged.
contract StripSpaceXForkTest is Test {
    StripLive live;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("hood"));
        Live.Feed[] memory nine = Feeds.all();
        Live.Feed[] memory f = new Live.Feed[](nine.length + 1);
        for (uint256 i; i < nine.length; ++i) f[i] = nine[i];
        f[nine.length] = SpaceX.feed();
        live = new StripLive(new StripEngine(), f);
    }

    function test_SpaceXFeedPublishesOnMovement() public view {
        (uint256 varStep, uint256 threshold, uint256 prints, uint256 tradingSeconds) = live.cadence(9, 64);
        console.log("SPCX prints", prints, "trading seconds", tradingSeconds);
        console.log("SPCX threshold bps", threshold / 1e14, "varStep", varStep);
        assertGt(prints, 20, "too few prints in 64 rounds");
        assertGt(threshold, 40e14, "threshold below 40 bps is not a deviation feed");
        assertLt(threshold, 80e14, "threshold above 80 bps is not a half-percent feed");
        assertGt(varStep, 0);
    }

    function test_SpaceXStripUnderBudget() public view {
        uint16[] memory bps = new uint16[](32);
        for (uint256 j; j < 32; ++j) bps[j] = uint16(9625 + 25 * j);
        StripLive.Request memory q = StripLive.Request(9, bps, true, 78, 3, 128, 64, 1, true);
        uint256 g = gasleft();
        StripLive.StripResult memory r = live.quoteStrip(q);
        g -= gasleft();
        console.log("SPCX spot", r.spot / 1e14, "gas", g);
        StripEngine.StrikeQuote memory atm = r.strip.quotes[15];
        console.log("SPCX atm call", atm.call, "put", atm.put);
        assertLt(g, 49_000_000, "one strip must fit under the public node's budget");
        assertGt(atm.call, 0);
        assertGt(atm.put, 0);
        for (uint256 j = 1; j < 32; ++j) {
            assertLe(r.strip.quotes[j].call, r.strip.quotes[j - 1].call + 1, "call must not rise with strike");
            assertGe(r.strip.quotes[j].put + 1, r.strip.quotes[j - 1].put, "put must not fall with strike");
        }
    }
}
