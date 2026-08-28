// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Engine} from "./Engine.sol";

interface IAggregator {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

/// The engine bound to an equity feed. First step: spot only.
contract Live {
    Engine public immutable engine;
    address public immutable aggregator;

    constructor(Engine e, address a) { engine = e; aggregator = a; }

    function spot() external view returns (uint256 price, uint256 updatedAt) {
        IAggregator a = IAggregator(aggregator);
        (, int256 p,, uint256 u,) = a.latestRoundData();
        require(p > 0, "no price");
        price = uint256(p) * 10 ** (18 - a.decimals());
        updatedAt = u;
    
    function cadenceEstimate(uint256[] memory dChanges, uint256[] memory gaps)
        internal pure returns (uint256 varStep)
    {
        // placeholder: this belongs on-chain, wired to the aggregator's own
        // round history, not to arrays. Sketch here first.
        require(gaps.length == dChanges.length, "shape");
    }
}
