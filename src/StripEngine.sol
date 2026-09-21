// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Engine} from "./Engine.sol";
import {EngineV2} from "./EngineV2.sol";

/// One set of simulated terminal prices or session averages prices an entire
/// strike strip. Antithetic mode shares the sign-invariant GARCH variance walk.
/// Sampling errors treat each mirrored pair as ONE independent observation.
/// It is an estimator under the engine's model.
contract StripEngine is EngineV2 {
    uint256 public constant MAX_STRIKES = 32;
    error BadStrikes();
    error BadPairCount();

    struct StrikeQuote {
        uint256 strike;
        uint256 call;
        uint256 put;
        uint256 callSe;
        uint256 putSe;
    }
    struct Strip {
        StrikeQuote[] quotes;
        uint256 underlyingMean;
        uint256 paths;
        uint256 independentSamples;
    }
    struct Moments {
        uint256[] callSum;
        uint256[] callSq;
        uint256[] putSum;
        uint256[] putSq;
        uint256 underlyingSum;
    }

    /// s.strike is unused. s.payoff selects terminal vs arithmetic-average
    /// underlying; each requested strike returns BOTH calls and puts.
    /// s.paths counts physical paths. Paired mode requires an even count >= 4.
    function quoteStrip(Engine.Spec memory s, uint256[] memory strikes, bool paired)
        public pure returns (Strip memory result)
    {
        if (s.paths < 2 || s.steps == 0 || s.spot == 0 || s.every == 0 || s.steps % s.every != 0) revert BadSpec();
        if (s.alpha + s.beta >= ONE) revert BadSpec();
        uint256 k = strikes.length;
        if (k == 0 || k > MAX_STRIKES) revert BadStrikes();
        for (uint256 j = 1; j < k; ++j) if (strikes[j] <= strikes[j - 1]) revert BadStrikes();
        if (paired && (s.paths < 4 || s.paths % 2 != 0)) revert BadPairCount();
        uint256 width = paired ? 2 : 1;
        uint256 n = s.paths / width;
        Moments memory m = Moments(new uint256[](k), new uint256[](k), new uint256[](k), new uint256[](k), 0);
        uint256 sd0 = root(s.var0);
        for (uint256 p; p < n; ++p) {
            uint256 a;
            uint256 b;
            if (paired) (a, b) = pairValues(s, p, sd0);
            else a = pathValue(s, p, sd0);
            m.underlyingSum += a + b;
            for (uint256 j; j < k; ++j) {
                uint256 strike = strikes[j];
                uint256 c = a > strike ? a - strike : 0;
                uint256 put = a < strike ? strike - a : 0;
                if (paired) {
                    c += b > strike ? b - strike : 0;
                    put += b < strike ? strike - b : 0;
                }
                m.callSum[j] += c; m.callSq[j] += c * c;
                m.putSum[j] += put; m.putSq[j] += put * put;
            }
        }
        result.quotes = new StrikeQuote[](k);
        result.underlyingMean = m.underlyingSum / s.paths;
        result.paths = s.paths;
        result.independentSamples = n;
        for (uint256 j; j < k; ++j) {
            (uint256 c, uint256 cs) = finish(m.callSum[j], m.callSq[j], n, width);
            (uint256 p, uint256 ps) = finish(m.putSum[j], m.putSq[j], n, width);
            result.quotes[j] = StrikeQuote(strikes[j], c, p, cs, ps);
        }
    }

    function finish(uint256 sum, uint256 sq, uint256 n, uint256 width)
        internal pure returns (uint256 mean, uint256 se)
    {
        uint256 unitMean = sum / n;
        uint256 e2 = sq / n;
        uint256 m2 = unitMean * unitMean;
        uint256 variance = e2 > m2 ? ((e2 - m2) * n) / (n - 1) : 0;
        mean = sum / (n * width);
        se = isqrt(variance / n) / width;
    }

    /// Under r -> -r, r^2 and every subsequent variance are unchanged.
    /// Hashes, variance updates and square roots are computed once per pair.
    function pairValues(Engine.Spec memory s, uint256 p, uint256 sd0)
        internal pure returns (uint256 a, uint256 b)
    {
        bool asian = uint8(s.payoff) >= 2;
        uint256 v = s.var0;
        uint256 sd = sd0;
        int256 logA;
        int256 logB;
        uint256 accA;
        uint256 accB;
        for (uint256 t; t < s.steps; ++t) {
            int256 r = (int256(sd) * normal(s.seed, p, t)) / int256(ONE);
            int256 drift = int256(v / 2);
            logA += r - drift;
            logB += -r - drift;
            v = s.omega + (s.alpha * uint256((r * r) / int256(ONE))) / ONE + (s.beta * v) / ONE;
            sd = warmRoot(v, sd);
            if (asian && (t + 1) % s.every == 0) {
                accA += exp(logA);
                accB += exp(logB);
            }
        }
        if (asian) {
            uint256 observations = s.steps / s.every;
            a = (s.spot * (accA / observations)) / ONE;
            b = (s.spot * (accB / observations)) / ONE;
        } else {
            a = (s.spot * exp(logA)) / ONE;
            b = (s.spot * exp(logB)) / ONE;
        }
    }
}
