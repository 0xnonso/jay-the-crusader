// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "../src/Crusader.sol";
import "forge-std/Script.sol";

contract StartScript is Script {
    Crusader crusader = Crusader(payable(0x389A9fAb91077b848fb11C90bcBcE2a482dE41Ca));
    JAY public immutable jay = JAY(payable(0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E));
    function setUp() public {}

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        if(crusader.getJUniSpotPriceETH() > jay.JAYtoETH(1e18)){
            crusader.startCrusade(5e18);
        } else {
            crusader.startCrusade(5000e6);
        }

        vm.stopBroadcast();
    }
}
