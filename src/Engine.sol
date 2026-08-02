// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// A Monte Carlo option engine that runs inside a view call and reports its
/// own error.
contract Engine {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant PASSES = 5;

    struct Spec {
        uint256 spot;
        uint256 strike;
        uint256 var0;
        uint256 omega;
        uint256 alpha;
        uint256 beta;
        uint16 steps;
        uint16 paths;
        uint256 seed;
    }

    error BadSpec();

    function quote(Spec memory s) public pure returns (uint256 mean, uint256 se) {
        if (s.paths < 2 || s.steps == 0 || s.spot == 0) revert BadSpec();
        if (s.alpha + s.beta >= ONE) revert BadSpec();
        uint256 sd0 = root(s.var0);
        uint256 sum;
        uint256 sq;
        for (uint256 p; p < s.paths; ++p) {
            uint256 pay = path(s, p, sd0);
            sum += pay;
            sq += pay * pay;
        }
        uint256 n = s.paths;
        mean = sum / n;
        uint256 m2 = mean * mean;
        uint256 e2 = sq / n;
        uint256 v = e2 > m2 ? ((e2 - m2) * n) / (n - 1) : 0;
        se = isqrt(v / n);
    }

    function path(Spec memory s, uint256 p, uint256 sd0) internal pure returns (uint256) {
        uint256 sd = sd0;
        uint256 v = s.var0;
        int256 logS;
        for (uint256 t; t < s.steps; ++t) {
            int256 r = (int256(sd) * normal(s.seed, p, t)) / int256(ONE);
            logS += r - int256(v / 2);
            v = s.omega + (s.alpha * uint256((r * r) / int256(ONE))) / ONE + (s.beta * v) / ONE;
            sd = warmRoot(v, sd);
        }
        uint256 S = (s.spot * exp(logS)) / ONE;
        return S > s.strike ? S - s.strike : 0;
    }

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

    function isqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        y = x;
        uint256 k = (x >> 1) + 1;
        while (k < y) { y = k; k = (x / k + k) >> 1; }
    }

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
