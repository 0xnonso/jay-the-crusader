// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {JAY} from "./deps/JayERC20.sol";
import {UniswapV2Library} from "./deps/UniswapV2Library.sol";
import {IWETH9} from "./deps/interface.sol";
import "v2-core/interfaces/IUniswapV2Pair.sol";
import "v2-core/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import { UD60x18, ud, unwrap } from "prb-math/UD60x18.sol";

// Arb JAY <-> JAY/USDC UNIV2 Pool
contract Crusader {
    using SafeMath for uint256;
    using Math for uint256;

    address public constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address payable constant weth = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public immutable factoryV2 = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; 
    JAY public immutable jay = JAY(payable(0xDA7C0810cE6F8329786160bb3d1734cf6661CA6E));

    function startCrusade(
        uint256 amount
    ) external {
        //   (((((( in  ,  out ))))))
        (address token0, address token1) = _tokens();

         // get pair contract
        address pair = IUniswapV2Factory(factoryV2).getPair(
            token0,
            token1
        );

        (uint256 _amountIn, uint256 _amountOut) = token0 == IUniswapV2Pair(pair).token0()
            ? (amount, uint256(0))
            : (uint256(0), amount);

        require(pair != address(0), "!pair");

        // need to pass some data to trigger uniswapv2call
        bytes memory data = abi.encode(token0, token1);
        // last parameter tells whether its a normal swap or a flash swap
        IUniswapV2Pair(pair).swap(_amountIn, _amountOut, address(this), data);
    
        IERC20(token1).transferFrom(
            address(this), 
            msg.sender,
            IERC20(token1).balanceOf(address(this))
        );
        
    }

    // outputs either weth or usdc
    function jArb(
        address token0,
        address token1,
        uint256 amountIn
    ) public {
        if(token0 == usdc){
            // usdc -> jay -> eth 
            (, uint256 realAfterBalance) = calculateSwapV2(
                amountIn, 
                IUniswapV2Factory(factoryV2).getPair(
                    token0,
                    address(jay)
                ), 
                token0, 
                address(jay)
            );
            _jayneth(address(jay), realAfterBalance);
            IWETH9(weth).deposit{value: address(this).balance}();

        } else {
            //convert weth to eth
            // eth -> jay -> usdc
            IWETH9(weth).deposit{value: amountIn}();
            calculateSwapV2(
                _jayneth(token0, amountIn), //unwrap
                IUniswapV2Factory(factoryV2).getPair(
                    token1,
                    address(jay)
                ), 
                address(jay), 
                token1
            );
        }
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        address pair = IUniswapV2Factory(factoryV2).getPair(
            IUniswapV2Pair(msg.sender).token0(), // fetch the address of token0
            IUniswapV2Pair(msg.sender).token1()  // fetch the address of token1
        );
        require(msg.sender == pair); // ensure that msg.sender is a V2 pair
        require(sender == address(this));

        (address token0, address token1) = abi.decode(data, (address, address));

        uint256 amount = amount0.max(amount1);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        uint256 amountOut = UniswapV2Library.getAmountIn(amount, reserve1, reserve0);
     
        jArb(token0, token1, amount);

        require(IERC20(token1).balanceOf(address(this)) > amountOut, "Sorry Jay: Still stuck in the trenches");
        IERC20(token1).transfer(pair, amountOut); // repay loan
    }

    // https://github.com/mouseless-eth/rusty-sando/blob/master/contract/src/BrainDance.sol#L13
    function calculateSwapV2(
        uint amountIn, 
        address targetPair, 
        address inputToken, 
        address outputToken
    ) public returns (uint amountOut, uint realAfterBalance){
        // Optimistically send amountIn of inputToken to targetPair
        IERC20(inputToken).transfer(targetPair, amountIn);

        // Prepare variables for calculating expected amount out
        uint reserveIn;
        uint reserveOut;

        { // Avoid stack too deep error
            (uint reserve0, uint reserve1,) = IUniswapV2Pair(targetPair).getReserves();

            // sort reserves
            if (inputToken < outputToken) {
                // Token0 is equal to inputToken
                // Token1 is equal to outputToken
                reserveIn = reserve0;
                reserveOut = reserve1;
            } else {
                // Token0 is equal to outputToken
                // Token1 is equal to inputToken
                reserveIn = reserve1;
                reserveOut = reserve0;
            }
        }

        // Find the actual amountIn sent to pair (accounts for tax if any) and amountOut
        uint actualAmountIn = IERC20(inputToken).balanceOf(address(targetPair)).sub(reserveIn);
        amountOut = UniswapV2Library.getAmountOut(actualAmountIn, reserveIn, reserveOut);

        // Prepare swap variables and call pair.swap()
        (uint amount0Out, uint amount1Out) = inputToken < outputToken ? (uint(0), amountOut) : (amountOut, uint(0));
        IUniswapV2Pair(targetPair).swap(amount0Out, amount1Out, address(this), new bytes(0));

        // Find real balance after (accounts for taxed tokens)
        realAfterBalance = IERC20(outputToken).balanceOf(address(this));
    }


    function _jayneth(address tokenIn, uint256 amount) internal returns(uint256){
        if(tokenIn != address(jay)){
            jay.buy{value: amount}(address(this));
            return jay.getBuyJay(amount);
        } else {
            jay.sell(amount);
            return jay.getSellJay(amount);
        }
    }

    // arb order
    function _tokens() internal  view returns(address,address){
        if(jay.JAYtoETH(1e18) == getJUniSpotPriceETH()) revert("POOL_BALANCED");
        return jay.JAYtoETH(1e18) > getJUniSpotPriceETH()
                ? (usdc, address(weth))
                : (address(weth), usdc)
        ;
    }

    function getJUniSpotPriceETH() public view returns(uint256){
        address juPair = IUniswapV2Factory(factoryV2).getPair(address(jay), usdc);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(juPair).getReserves();
        UD60x18 jayToUsdc = IUniswapV2Pair(juPair).token0() == usdc 
            ? ud(reserve0 * 1e12).div(ud(reserve1))
            : ud(reserve1).div(ud(reserve0 * 1e12));
        
        address euPair = IUniswapV2Factory(factoryV2).getPair(usdc, weth);
        (reserve0, reserve1,) = IUniswapV2Pair(euPair).getReserves();
        UD60x18 usdcToEth = IUniswapV2Pair(euPair).token0() == usdc 
            ? ud(reserve1).div(ud(reserve0 * 1e12))
            : ud(reserve0 * 1e12).div(ud(reserve1));

        return unwrap(usdcToEth.mul(jayToUsdc));
    }

    receive() external payable {}
}