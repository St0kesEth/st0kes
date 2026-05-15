// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

/// The engine's arithmetic pieces, tested on their own so a change is
/// attributed to the piece it changed.
contract SqrtTest is Test {
    uint256 constant ONE = 1e18;

    function test_KnownRoots() public pure {
        assertEq(newton(1e18), 1e18);
        assertEq(newton(4e18) / 1e9, 2e18 / 1e9);
    }

    function newton(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = n;
        uint256 k = (n >> 1) + 1;
        while (k < y) { y = k; k = (n / k + k) >> 1; }
    }
}
