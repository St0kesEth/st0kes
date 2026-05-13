// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// Fixed-point arithmetic pieces the option engine will need.
contract Engine {
    uint256 internal constant ONE = 1e18;

    /// Square root of a 1e18 fixed-point number, from scratch.
    function root(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = n;
        uint256 k = (n >> 1) + 1;
        while (k < y) { y = k; k = (n / k + k) >> 1; }
    }
}
