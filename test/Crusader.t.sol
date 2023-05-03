// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Crusader.sol";

contract CrusaderTest is Test {
    Crusader public crusader;
     JAY public immutable jay = JAY(payable(0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E));
     address payable constant weth = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        crusader = new Crusader();
    }

    function testCrusade() public {
        //vm.deal(address(crusader), 10e18);
        if(crusader.getJUniSpotPriceETH() > jay.JAYtoETH(1e18)){
            crusader.startCrusade(5e18);
        } else {
            crusader.startCrusade(10000e6);
        }
    }
    function testPrice() public {
        console.log(
            crusader.getJUniSpotPriceETH()
        );
        console.log(jay.JAYtoETH(1e18));
    }
}
