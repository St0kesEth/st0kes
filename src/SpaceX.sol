// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Live} from "./Live.sol";

/// The SpaceX feed on Robinhood Chain. SpaceX is private, so there is no bar
/// history to fit a variance memory to; the walk keeps the variance the feed's
/// rhythm gives it for the whole session (alpha 0, beta one less a wei, the
/// closest the engine allows to a constant).
library SpaceX {
    function feed() internal pure returns (Live.Feed memory) {
        return Live.Feed(0x5eaa223c585F40CDcA2D119ea91B97C491245631, "SPCX", 0, 0, 1e18 - 1);
    }
}
