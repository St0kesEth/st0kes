// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";

contract EngineTest is Test {
    Engine e;
    uint256 constant SPOT = 100e18;

    function setUp() public { e = new Engine(); }

    function brownian(Engine.Payoff pay, uint256 strike, uint16 paths, uint256 seed) internal view returns (Engine.Spec memory s) {
        uint256 v = vm.parseJsonUint(vm.readFile("data/reference.json"), ".varStep");
        s = Engine.Spec(pay, SPOT, strike, v, v, 0, 0, 78, 1, paths, seed);
    }

    function bursty(Engine.Payoff pay, uint256 strike, uint16 paths, uint256 seed) internal pure returns (Engine.Spec memory s) {
        uint256 v = 4e12; uint256 a = 0.2166e18; uint256 b = 0.7293e18;
        s = Engine.Spec(pay, SPOT, strike, v, (v * (1e18 - a - b)) / 1e18, a, b, 78, 3, paths, seed);
    }

    function test_Deterministic() public view {
        (uint256 a, uint256 sa) = e.quote(bursty(Engine.Payoff.AsianCall, SPOT, 64, 42));
        (uint256 b, uint256 sb) = e.quote(bursty(Engine.Payoff.AsianCall, SPOT, 64, 42));
        assertEq(a, b); assertEq(sa, sb);
    }
}

    /// Same paths price the call and the put, so call minus put must equal
    /// spot minus strike up to the noise the quote reports.
    function test_AsianPutCallParity() public view {
        (uint256 c, uint256 sc) = e.quote(bursty(Engine.Payoff.AsianCall, 101e18, 256, 7));
        (uint256 p, uint256 sp) = e.quote(bursty(Engine.Payoff.AsianPut, 101e18, 256, 7));
        int256 lhs = int256(c) - int256(p);
        int256 rhs = int256(SPOT) - int256(101e18);
        uint256 gap = uint256(lhs > rhs ? lhs - rhs : rhs - lhs);
        assertLt(gap, 4 * (sc > sp ? sc : sp));
    }
}
