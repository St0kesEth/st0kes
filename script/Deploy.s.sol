// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Engine} from "../src/Engine.sol";
import {Live} from "../src/Live.sol";
import {Feeds} from "../src/Feeds.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Engine engine = new Engine();
        Live live = new Live(engine, Feeds.all());
        vm.stopBroadcast();
        console.log("Engine", address(engine));
        console.log("Live  ", address(live));
    }
}
