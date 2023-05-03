// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/Crusader.sol";
import "forge-std/Script.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        new Crusader();

        vm.stopBroadcast();
    }
}
