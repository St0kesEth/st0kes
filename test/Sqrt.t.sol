// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

/// The arithmetic pieces, tested on their own.
contract SqrtTest is Test {
    uint256 constant ONE = 1e18;

    function test_KnownRoots() public pure {
        assertEq(cold(1e18), 1e18);
        assertEq(cold(4e18) / 1e9, 2e18 / 1e9);
    }

    /// Five Newton passes from the last root should land close to the new one.
    function test_WarmClosesTheGap() public pure {
        uint256 v0 = 0.04e18;
        uint256 r0 = cold(v0);
        uint256 v1 = 0.041e18;
        uint256 warmed = warm(v1, r0, 5);
        uint256 exact = cold(v1);
        uint256 gap = warmed > exact ? warmed - exact : exact - warmed;
        assertLt(gap, 1e10);
    }

    function cold(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = n;
        uint256 k = (n >> 1) + 1;
        while (k < y) { y = k; k = (n / k + k) >> 1; }
    }
    function warm(uint256 x, uint256 g, uint256 passes) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = g == 0 ? x : g;
        for (uint256 i; i < passes; ++i) y = (y + n / y) >> 1;
    }
}
