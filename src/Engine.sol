// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// Fixed-point arithmetic pieces for a Monte Carlo option engine.
contract Engine {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant PASSES = 5;

    function root(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = n;
        uint256 k = (n >> 1) + 1;
        while (k < y) { y = k; k = (n / k + k) >> 1; }
    }

    function warmRoot(uint256 x, uint256 g) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = g == 0 ? x : g;
        for (uint256 i; i < PASSES; ++i) y = (y + n / y) >> 1;
    }

    /// A standard normal from one hash: twelve 21-bit uniforms, summed and centred.
    function normal(uint256 seed, uint256 p, uint256 t) internal pure returns (int256 z) {
        assembly ("memory-safe") {
            mstore(0x00, seed)
            mstore(0x20, or(shl(32, p), t))
            let h := keccak256(0x00, 0x40)
            let m := 0x1FFFFF
            let s := and(h, m)
            s := add(s, and(shr(21, h), m))    s := add(s, and(shr(42, h), m))
            s := add(s, and(shr(63, h), m))    s := add(s, and(shr(84, h), m))
            s := add(s, and(shr(105, h), m))   s := add(s, and(shr(126, h), m))
            s := add(s, and(shr(147, h), m))   s := add(s, and(shr(168, h), m))
            s := add(s, and(shr(189, h), m))   s := add(s, and(shr(210, h), m))
            s := add(s, and(shr(231, h), m))
            z := sdiv(mul(sub(s, mul(6, m)), 1000000000000000000), shl(21, 1))
        }
    }

    /// e to a 1e18 fixed-point power, argument-reduced.
    function exp(int256 x) internal pure returns (uint256) {
        if (x < -40e18) return 0;
        require(x <= 40e18, "exp overflow");
        bool neg = x < 0;
        uint256 ax = uint256(neg ? -x : x);
        uint256 n = ax / ONE;
        uint256 f = ax % ONE;
        uint256 term = ONE;
        uint256 ef = ONE;
        for (uint256 i = 1; i <= 12; ++i) {
            term = (term * f) / (ONE * i);
            ef += term;
            if (term == 0) break;
        }
        uint256 e = 2718281828459045235;
        uint256 en = ONE;
        for (uint256 i; i < n; ++i) en = (en * e) / ONE;
        uint256 r = (en * ef) / ONE;
        return neg ? (ONE * ONE) / r : r;
    }
}
