// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Crusader.sol";

contract CrusaderTest is Test {
    Crusader public crusader;
     JAY public immutable jay = JAY(payable(0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E));

    function setUp() public {
        crusader = new Crusader();
    }

    function testCrusade() public {
        crusader.startCrusade(10000e6);
    }
    function testPrice() public {
        console.log(
            crusader.getJUniSpotPriceETH()
        );
        console.log(jay.JAYtoETH(1e18));
    }
}
