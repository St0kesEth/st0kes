// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";

contract EngineTest is Test {
    Engine e;
    uint256 constant SPOT = 100e18;
    function setUp() public { e = new Engine(); }

    function spec(uint16 paths, uint256 seed) internal pure returns (Engine.Spec memory s) {
        s = Engine.Spec(SPOT, SPOT, 4e12, 78, paths, seed);
    }

    function test_Deterministic() public view {
        assertEq(e.quote(spec(64, 42)), e.quote(spec(64, 42)));
    }

    function test_RejectsBadSpec() public {
        Engine.Spec memory s = spec(1, 1); s.spot = 0;
        vm.expectRevert(Engine.BadSpec.selector); e.quote(s);
    }
}
