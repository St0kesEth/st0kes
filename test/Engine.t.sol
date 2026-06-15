// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";

/// Engine skeleton: no path yet, only the moments of the sampler and the
/// closed form of the exponential.
contract EngineTest is Test {
    Engine e;
    function setUp() public { e = new Engine(); }
    function test_Constructs() public view { assertTrue(address(e) != address(0)); }
}
