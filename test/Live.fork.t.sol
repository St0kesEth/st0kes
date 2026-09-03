// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";
import {Live} from "../src/Live.sol";
import {Feeds} from "../src/Feeds.sol";

contract LiveForkTest is Test {
    uint256 constant BLOCK = 67367297;
    Live live;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("hood"), BLOCK);
        live = new Live(new Engine(), Feeds.all());
    }

    function test_CadenceOnEveryFeed() public view {
        Live.Feed[] memory f = live.feeds();
        for (uint256 i; i < f.length; ++i) {
            (uint256 v, uint256 thr,,) = live.cadence(i, 64);
            assertGt(thr, 0.002e18); assertLt(thr, 0.02e18);
            console.log(f[i].symbol, "sd/step (bps)", isqrt(v * 1e18) / 1e14);
        }
    }

    function isqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        y = x; uint256 k = (x >> 1) + 1;
        while (k < y) { y = k; k = (x / k + k) >> 1; }
    }
}
