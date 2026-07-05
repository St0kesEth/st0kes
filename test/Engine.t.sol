// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";

contract EngineTest is Test {
    Engine e;
    uint256 constant SPOT = 100e18;
    function setUp() public { e = new Engine(); }

    function spec(uint256 strike, uint16 paths, uint256 seed) internal view returns (Engine.Spec memory s) {
        uint256 v = vm.parseJsonUint(vm.readFile("data/reference.json"), ".varStep");
        s = Engine.Spec(SPOT, strike, v, 78, paths, seed);
    }

    function test_Deterministic() public view {
        assertEq(e.quote(spec(SPOT, 64, 42)), e.quote(spec(SPOT, 64, 42)));
    }

    function test_BrownianMatchesBlackScholes() public view {
        string memory ref = vm.readFile("data/reference.json");
        uint256 exact = vm.parseJsonUint(ref, ".call100");
        uint256 sum;
        for (uint256 k = 1; k <= 40; ++k) sum += e.quote(spec(SPOT, 128, k));
        uint256 mean = sum / 40;
        uint256 gap = mean > exact ? mean - exact : exact - mean;
        console.log("mean", mean, "exact", exact);
        assertLt(gap, exact / 10);
    }

    function test_RejectsBadSpec() public {
        Engine.Spec memory s = spec(SPOT, 1, 1); s.spot = 0;
        vm.expectRevert(Engine.BadSpec.selector); e.quote(s);
    }
}
