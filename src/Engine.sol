// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// Fixed-point arithmetic pieces the option engine will need.
contract Engine {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant PASSES = 5;

    /// Square root of a 1e18 fixed-point number, from scratch.
    function root(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = n;
        uint256 k = (n >> 1) + 1;
        while (k < y) { y = k; k = (n / k + k) >> 1; }
    }

    /// The same root, started from the previous step's answer. Five Newton passes.
    function warmRoot(uint256 x, uint256 g) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = g == 0 ? x : g;
        for (uint256 i; i < PASSES; ++i) y = (y + n / y) >> 1;
    }
}
