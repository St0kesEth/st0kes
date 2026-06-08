// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Rand} from "../src/Rand.sol";

contract RandTest is Test {
    /// A thousand draws should look like a standard normal: mean near zero,
    /// variance near one, fourth moment near three.
    function test_Moments() public pure {
        int256 sum;
        uint256 sq;
        uint256 q4;
        for (uint256 i; i < 1024; ++i) {
            int256 z = Rand.normal(1, i, 0);
            sum += z;
            sq += uint256((z * z) / 1e18);
            uint256 z2 = uint256((z * z) / 1e18);
            q4 += (z2 * z2) / 1e18;
        }
        int256 mean = sum / 1024;
        assertLt(mean > 0 ? uint256(mean) : uint256(-mean), 5e16);
        assertGt(sq / 1024, 0.9e18);
        assertLt(sq / 1024, 1.1e18);
        assertGt(q4 / 1024, 2.5e18);
        assertLt(q4 / 1024, 3.5e18);
    }
}
