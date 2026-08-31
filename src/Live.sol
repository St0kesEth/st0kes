// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Engine} from "./Engine.sol";

interface IAggregator {
    function decimals() external view returns (uint8);
    function latestRound() external view returns (uint256);
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function getRoundData(uint80 id) external view returns (uint80, int256, uint256, uint256, uint80);
}

/// The engine bound to live equity feeds. Spot is the feed's latest answer,
/// the variance the walk starts from is read off the feed's own publishing
/// rhythm, and the coefficients of the recursion are the per-ticker fits
/// published with the paper. Nothing here is owned or updatable.
contract Live {
    uint256 internal constant ONE = 1e18;
    uint256 public constant STEP = 300;         // one step of the walk is five minutes
    uint256 public constant SESSION_GAP = 7200; // a gap longer than this is not trading time

    struct Feed {
        address aggregator;
        string symbol;
        uint256 omega; // per five-minute step, 1e18
        uint256 alpha; // 1e18
        uint256 beta;  // 1e18
    }

    struct Result {
        uint256 mean;      // 1e18, spot units
        uint256 se;        // 1e18, spot units
        uint256 spot;      // 1e18
        uint256 updatedAt; // when the feed last published
        uint256 varStep;   // variance of one step, 1e18
        uint256 seed;
    }

    Engine public immutable engine;
    Feed[] internal feeds_;

    constructor(Engine e, Feed[] memory f) {
        engine = e;
        for (uint256 i; i < f.length; ++i) feeds_.push(f[i]);
    }

    function feeds() external view returns (Feed[] memory) { return feeds_; }

    /// Spot in 1e18 and when the feed last published.
    function spot(uint256 i) public view returns (uint256 price, uint256 updatedAt) {
        IAggregator a = IAggregator(feeds_[i].aggregator);
        (, int256 p,, uint256 u,) = a.latestRoundData();
        require(p > 0, "no price");
        price = uint256(p) * 10 ** (18 - a.decimals());
        updatedAt = u;
    }

    /// Variance of one five-minute step, read from the feed's own rhythm over
    /// its last `rounds` rounds. A deviation feed publishes when the price has
    /// moved by its threshold, so the threshold squared, times publications per
    /// second of trading time, is the variance per second. The threshold is the
    /// median absolute change between consecutive answers; trading time is the
    /// sum of the gaps shorter than SESSION_GAP.
    function cadence(uint256 i, uint256 rounds)
        public view returns (uint256 varStep, uint256 threshold, uint256 prints, uint256 tradingSeconds)
    {
        IAggregator a = IAggregator(feeds_[i].aggregator);
        uint256 last = a.latestRound();
        require(rounds >= 8 && rounds <= 512 && last > rounds, "rounds");
        uint256[] memory ch = new uint256[](rounds);
        (, int256 p0,, uint256 t0,) = a.getRoundData(uint80(last - rounds));
        for (uint256 k = 1; k <= rounds; ++k) {
            (, int256 p1,, uint256 t1,) = a.getRoundData(uint80(last - rounds + k));
            if (t1 > t0 && t1 - t0 < SESSION_GAP) { tradingSeconds += t1 - t0; prints += 1; }
            if (p0 > 0 && p1 > 0) {
                uint256 d = p1 > p0 ? uint256(p1 - p0) : uint256(p0 - p1);
                ch[k - 1] = (d * ONE) / uint256(p0);
            }
            p0 = p1;
            t0 = t1;
        }
        require(tradingSeconds > 0, "no trading time in window");
        threshold = median(ch);
        varStep = (((threshold * threshold) / ONE) * prints * STEP) / tradingSeconds;
    }

    /// A quote from live inputs. `strike` 0 means at the money; `seed` 0 means
    /// the current block, so the same call gives a fresh draw every block and
    /// the reader can watch the estimate move inside its own error bar.
    function quote(
        uint256 i, Engine.Payoff payoff, uint256 strike,
        uint16 steps, uint16 every, uint16 paths, uint256 rounds, uint256 seed
    ) external view returns (Result memory r) {
        (r.spot, r.updatedAt) = spot(i);
        (r.varStep,,,) = cadence(i, rounds);
        r.seed = seed == 0 ? block.number : seed;
        Feed memory f = feeds_[i];
        (r.mean, r.se) = engine.quote(Engine.Spec(
            payoff, r.spot, strike == 0 ? r.spot : strike, r.varStep,
            f.omega, f.alpha, f.beta, steps, every, paths, r.seed
        ));
    }

    function median(uint256[] memory a) internal pure returns (uint256) {
        for (uint256 i = 1; i < a.length; ++i) {
            uint256 x = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > x) { a[j] = a[j - 1]; --j; }
            a[j] = x;
        }
        uint256 n = a.length;
        return n % 2 == 1 ? a[n / 2] : (a[n / 2 - 1] + a[n / 2]) / 2;
    }
}
