// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Engine} from "../src/Engine.sol";

/// Bench the pieces on their own so a saving is attributed to the piece it
/// changed. There is no path yet, only the arithmetic.
contract BenchTest is Test {}
