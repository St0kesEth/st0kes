// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Live} from "../src/Live.sol";
import {StripEngine} from "../src/StripEngine.sol";
import {StripLive} from "../src/StripLive.sol";
import {Feeds} from "../src/Feeds.sol";
import {SpaceX} from "../src/SpaceX.sol";

/// A second StripLive on the deployed StripEngine: the nine feeds of the paper
/// and SpaceX as the tenth (index 9).
contract DeployStripSpaceX is Script {
    StripEngine constant ENGINE = StripEngine(0x754F761B639996E2E315d17D25a43710c50eba23);

    function feeds() internal pure returns (Live.Feed[] memory f) {
        Live.Feed[] memory nine = Feeds.all();
        f = new Live.Feed[](nine.length + 1);
        for (uint256 i; i < nine.length; ++i) f[i] = nine[i];
        f[nine.length] = SpaceX.feed();
    }

    function run() external {
        vm.startBroadcast();
        StripLive live = new StripLive(ENGINE, feeds());
        vm.stopBroadcast();
        console.log("StripLive (with SpaceX)", address(live));
    }
}
