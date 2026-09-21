// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {StripEngine} from "../src/StripEngine.sol";
import {StripLive} from "../src/StripLive.sol";
import {Feeds} from "../src/Feeds.sol";

contract DeployStrip is Script {
    function run() external {
        vm.startBroadcast();
        StripEngine engine = new StripEngine();
        StripLive live = new StripLive(engine, Feeds.all());
        vm.stopBroadcast();
        console.log("StripEngine", address(engine));
        console.log("StripLive  ", address(live));
    }
}
