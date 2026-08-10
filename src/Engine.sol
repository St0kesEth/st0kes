// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// A Monte Carlo option engine that runs inside a view call and reports its
/// own error.
///
/// The walk carries a variance that feeds on itself: the size of each step is
/// drawn from the variance the previous step left behind (GARCH(1,1) in the
/// usual notation). With alpha and beta at zero the walk is geometric Brownian
/// motion. A quote is the mean payoff over the paths and the standard error of
/// that mean, so a reader can tell the number from the noise around it.
///
/// Stateless and unowned. The same spec and seed always give the same answer.
contract Engine {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant PASSES = 5; // Newton passes on the warm-started root

    enum Payoff { Call, Put, AsianCall, AsianPut }

    struct Spec {
        Payoff payoff;
        uint256 spot;    // 1e18
        uint256 strike;  // 1e18
        uint256 var0;    // variance of the first step's log return, 1e18
        uint256 omega;   // constant term of the variance recursion, per step, 1e18
        uint256 alpha;   // weight on the last squared return, 1e18
        uint256 beta;    // weight on the last variance, 1e18
        uint16 steps;    // steps per path
        uint16 every;    // Asian payoffs average the price every `every` steps
        uint16 paths;
        uint256 seed;
    }

    error BadSpec();

    /// Mean payoff over the paths and the standard error of that mean, both in
    /// the units of `spot`. Undiscounted: the walk is a martingale at zero rate.
    function quote(Spec memory s) public pure returns (uint256 mean, uint256 se) {
        if (s.paths < 2 || s.steps == 0 || s.spot == 0 || s.every == 0 || s.steps % s.every != 0) revert BadSpec();
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
        uint256 v = e2 > m2 ? ((e2 - m2) * n) / (n - 1) : 0; // sample variance of one payoff
        se = isqrt(v / n);
    }

    // ---- one path -----------------------------------------------------------

    function path(Spec memory s, uint256 p, uint256 sd0) internal pure returns (uint256) {
        bool asian = uint8(s.payoff) >= 2;
        uint256 v = s.var0;
        uint256 sd = sd0;
        int256 logS;
        uint256 acc;
        for (uint256 t; t < s.steps; ++t) {
            int256 r = (int256(sd) * normal(s.seed, p, t)) / int256(ONE);
            logS += r - int256(v / 2);
            v = s.omega + (s.alpha * uint256((r * r) / int256(ONE))) / ONE + (s.beta * v) / ONE;
            sd = warmRoot(v, sd);
            if (asian && (t + 1) % s.every == 0) acc += exp(logS);
        }
        uint256 S = asian
            ? (s.spot * (acc / (s.steps / s.every))) / ONE
            : (s.spot * exp(logS)) / ONE;
        if (s.payoff == Payoff.Call || s.payoff == Payoff.AsianCall) return S > s.strike ? S - s.strike : 0;
        return s.strike > S ? s.strike - S : 0;
    }

    // ---- arithmetic ---------------------------------------------------------

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

    /// Square root of a 1e18 fixed-point number, from scratch.
    function root(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = n;
        uint256 k = (n >> 1) + 1;
        while (k < y) { y = k; k = (n / k + k) >> 1; }
    }

    /// The same root, started from the previous step's answer.
    function warmRoot(uint256 x, uint256 g) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 n = x * ONE;
        y = g == 0 ? x : g;
        for (uint256 i; i < PASSES; ++i) y = (y + n / y) >> 1;
    }

    /// Plain integer square root.
    function isqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        y = x;
        uint256 k = (x >> 1) + 1;
        while (k < y) { y = k; k = (x / k + k) >> 1; }
    }

    /// e to a 1e18 fixed-point power.
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
