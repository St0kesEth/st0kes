// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Engine} from "./Engine.sol";

/// The strip's engine: the deployed Engine's walk with a root that is exact
/// from any starting guess, and the path value split out so a strike strip can
/// reuse it. It takes Engine's Spec and Payoff so callers see one interface.
/// The deployed Engine is left as it is on the chain.
///
/// The walk carries a variance that feeds on itself: the size of each step is
/// drawn from the variance the previous step left behind (GARCH(1,1) in the
/// usual notation). With alpha and beta at zero the walk is geometric Brownian
/// motion. A quote is the mean payoff over the paths and the standard error of
/// that mean, so a reader can tell the number from the noise around it.
///
/// Stateless and unowned. The same spec and seed always give the same answer.
contract EngineV2 {
    uint256 internal constant ONE = 1e18;
    /// Fast warm-start passes, followed by an exact integer convergence check.
    uint256 internal constant PASSES = 5;



    error BadSpec();

    /// Mean payoff over the paths and the standard error of that mean, both in
    /// the units of `spot`. Undiscounted, using a Gaussian zero-rate drift
    /// correction. The bounded normal approximation is not an exact Gaussian
    /// martingale, and SE measures sampling noise rather than model error.
    function quote(Engine.Spec memory s) public pure returns (uint256 mean, uint256 se) {
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

    function path(Engine.Spec memory s, uint256 p, uint256 sd0) internal pure returns (uint256) {
        uint256 S = pathValue(s, p, sd0);
        if (s.payoff == Engine.Payoff.Call || s.payoff == Engine.Payoff.AsianCall) return S > s.strike ? S - s.strike : 0;
        return s.strike > S ? s.strike - S : 0;
    }

    /// Terminal price or arithmetic observation average, before applying a strike.
    function pathValue(Engine.Spec memory s, uint256 p, uint256 sd0) internal pure returns (uint256) {
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
        return asian
            ? (s.spot * (acc / (s.steps / s.every))) / ONE
            : (s.spot * exp(logS)) / ONE;
    }

    // ---- arithmetic ---------------------------------------------------------

    /// A bounded normal approximation: twelve 21-bit uniforms, summed and centred.
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
        if (g == 0) return root(x);
        uint256 n = x * ONE;
        y = g;
        for (uint256 i; i < PASSES; ++i) {
            uint256 next = n / y;
            y = (y & next) + ((y ^ next) >> 1); // floor((y + next) / 2), without overflow
        }
        // Newton's first positive iterate is >= floor(sqrt(n)). Continue until
        // the descending sequence reaches that floor, including large shocks.
        uint256 q = n / y;
        while (q < y) {
            y = (y & q) + ((y ^ q) >> 1);
            q = n / y;
        }
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
