// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";

contract BenchTest is Test {
    Engine e;
    function setUp() public { e = new Engine(); }

    function bursty(uint16 paths) internal pure returns (Engine.Spec memory s) {
        uint256 v = 4e12; uint256 a = 0.2166e18; uint256 b = 0.7293e18;
        s = Engine.Spec(100e18, 100e18, v, (v * (1e18 - a - b)) / 1e18, a, b, 78, paths, 1);
    }

    function test_Gas() public view {
        uint16[3] memory P = [uint16(32), 64, 128];
        for (uint256 i; i < P.length; ++i) {
            uint256 g = gasleft(); e.quote(bursty(P[i])); uint256 used = g - gasleft();
            console.log("paths", P[i], "gas", used);
        }
    }
}
