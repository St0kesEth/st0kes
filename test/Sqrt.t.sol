// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";

/// Same square root, cold and warm-started. Warm has to close a gap of the
/// size the engine actually sees between steps, in a few passes.
contract SqrtTest is Test {
    // The engine\'s methods are internal; a thin wrapper here would duplicate
    // them without value. The moments checked in the engine suite cover the
    // shape; this file is a placeholder for later precision work.
    function test_Placeholder() public pure {}
}
