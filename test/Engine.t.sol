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

    function test_AsianPutCallParity() public view {
        (uint256 c, uint256 sc) = e.quote(bursty(Engine.Payoff.AsianCall, 101e18, 256, 7));
        (uint256 p, uint256 sp) = e.quote(bursty(Engine.Payoff.AsianPut, 101e18, 256, 7));
        int256 lhs = int256(c) - int256(p);
        int256 rhs = int256(SPOT) - int256(101e18);
        uint256 gap = uint256(lhs > rhs ? lhs - rhs : rhs - lhs);
        assertLt(gap, 4 * (sc > sp ? sc : sp));
    

    /// The average of a path moves less than its end, so the Asian call is cheaper.
    function test_AsianCheaperThanVanilla() public view {
        (uint256 a,) = e.quote(bursty(Engine.Payoff.AsianCall, SPOT, 512, 3));
        (uint256 v,) = e.quote(bursty(Engine.Payoff.Call, SPOT, 512, 3));
        assertLt(a, v);
    

    function test_BrownianMatchesBlackScholes() public view {
        string memory ref = vm.readFile("data/reference.json");
        check(brownian(Engine.Payoff.Call, 100e18, 128, 0), vm.parseJsonUint(ref, ".call100"));
        check(brownian(Engine.Payoff.Call, 102e18, 128, 0), vm.parseJsonUint(ref, ".call102"));
        check(brownian(Engine.Payoff.Put, 98e18, 128, 0), vm.parseJsonUint(ref, ".put98"));
    }

    function check(Engine.Spec memory s, uint256 exact) internal view {
        uint256 n = 100; uint256 sum; uint256 sq; uint256 seSum;
        for (uint256 k = 1; k <= n; ++k) {
            s.seed = k;
            (uint256 m, uint256 se) = e.quote(s);
            sum += m; sq += m * m; seSum += se;
        }
        uint256 mean = sum / n;
        uint256 spread = sqrt((sq / n - mean * mean) * n / (n - 1));
        uint256 seAvg = seSum / n;
        uint256 seOfMean = seAvg / 10;
        uint256 gap = mean > exact ? mean - exact : exact - mean;
        assertLt(gap, 3 * seOfMean, "mean off black-scholes");
        assertGt(spread * 100 / seAvg, 75, "reported error too large");
        assertLt(spread * 100 / seAvg, 130, "reported error too small");
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        y = x; uint256 k = (x >> 1) + 1;
        while (k < y) { y = k; k = (x / k + k) >> 1; }
    }
}
