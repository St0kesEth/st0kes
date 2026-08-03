// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";

contract EngineTest is Test {
    Engine e;
    uint256 constant SPOT = 100e18;
    function setUp() public { e = new Engine(); }

    function bursty(uint16 paths, uint256 seed) internal pure returns (Engine.Spec memory s) {
        uint256 v = 4e12; uint256 a = 0.2166e18; uint256 b = 0.7293e18;
        s = Engine.Spec(SPOT, SPOT, v, (v * (1e18 - a - b)) / 1e18, a, b, 78, paths, seed);
    }

    function brownian(uint256 strike, uint16 paths, uint256 seed) internal view returns (Engine.Spec memory s) {
        uint256 v = vm.parseJsonUint(vm.readFile("data/reference.json"), ".varStep");
        s = Engine.Spec(SPOT, strike, v, v, 0, 0, 78, paths, seed);
    }

    function test_Deterministic() public view {
        (uint256 a, uint256 sa) = e.quote(bursty(64, 42));
        (uint256 b, uint256 sb) = e.quote(bursty(64, 42));
        assertEq(a, b); assertEq(sa, sb);
    }

    function test_BrownianMatchesBlackScholes() public view {
        string memory ref = vm.readFile("data/reference.json");
        uint256 exact = vm.parseJsonUint(ref, ".call100");
        uint256 sum; uint256 seSum;
        for (uint256 k = 1; k <= 100; ++k) {
            (uint256 m, uint256 se) = e.quote(brownian(SPOT, 128, k));
            sum += m; seSum += se;
        }
        uint256 mean = sum / 100;
        uint256 seOfMean = (seSum / 100) / 10;
        uint256 gap = mean > exact ? mean - exact : exact - mean;
        assertLt(gap, 3 * seOfMean);
    }

    function test_RejectsBadSpec() public {
        Engine.Spec memory s = bursty(1, 1);
        vm.expectRevert(Engine.BadSpec.selector); e.quote(s);
    }
}
