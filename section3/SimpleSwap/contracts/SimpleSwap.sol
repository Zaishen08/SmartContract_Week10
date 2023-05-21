// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISimpleSwap} from "./interface/ISimpleSwap.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    ERC20 _tokenA;
    ERC20 _tokenB;
    uint256 _reserveA;
    uint256 _reserveB;

    constructor(address tokenA, address tokenB)
    ERC20("SimpleSwap", "SWAP"){
        require(tokenA.code.length > 0, "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(tokenB.code.length > 0, "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(tokenA != tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");

        // Smaller address will always be tokenA
        if(tokenA < tokenB){
            _tokenA = ERC20(tokenA);
            _tokenB = ERC20(tokenB);
        } else {
            _tokenA = ERC20(tokenB);
            _tokenB = ERC20(tokenA);
        }
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut) {

        ERC20 tokenA = _tokenA;
        ERC20 tokenB = _tokenB;
        uint256 reserveA = _reserveA;
        uint256 reserveB = _reserveB;

        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB), "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == address(tokenA) || tokenOut == address(tokenB), "SimpleSwap: INVALID_TOKEN_OUT");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        uint256 oldK = reserveA * reserveB;
        uint256 denom;

        if (tokenIn == address(tokenA)) {
            denom = (reserveA + amountIn);
            amountOut = reserveB - ((oldK - 1) / denom + 1); // Calculate newK which need to bigger than oldK
            updateReserves(reserveA + amountIn, reserveB - amountOut); // Update reserve
        } else {
            denom = (reserveB + amountIn);
            amountOut = reserveA - ((oldK - 1) / denom + 1);
            updateReserves(reserveA - amountOut, reserveB + amountIn);
        }

        ERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn); // Transfer tokenIn from msg.sender to pool
        ERC20(tokenOut).transfer(msg.sender, amountOut);                  // Transfer tokenOut from pool to msg.sender
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);    // Send swap event
    }

    function addLiquidity(uint256 amountAIn, uint256 amountBIn)
    external
    returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        require(amountAIn != 0 && amountBIn != 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        uint256 reserveA = _reserveA;
        uint256 reserveB = _reserveB;

        if (reserveA == 0 && reserveB == 0) { // Add liquidity when initial
            amountA = amountAIn;
            amountB = amountBIn;
        } else {
            amountB = amountAIn * reserveB / reserveA;  // Add liquidity according to ratio of reserves
            amountA = amountAIn;

            if (amountB > amountBIn) {
                amountA = amountBIn * reserveA / reserveB;
                amountB = amountBIn;
            }
        }

        liquidity = Math.sqrt(amountA * amountB); // Set liquidity
        _tokenA.transferFrom(msg.sender, address(this), amountA);
        _tokenB.transferFrom(msg.sender, address(this), amountB);
        _mint(msg.sender, liquidity); // Mint LP tokens to msg.sender
        updateReserves(reserveA + amountA, reserveB + amountB);

        emit AddLiquidity(msg.sender, amountA, amountB, liquidity);    // Send AddLiquidity Event
    }

    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        uint256 reserveA = _reserveA;
        uint256 reserveB = _reserveB;

        amountA = reserveA * liquidity / totalSupply();         // Compute amountA and amountB by ratio of liquidity and totalSupply
        amountB = reserveB * liquidity / totalSupply();

        this.transferFrom(msg.sender, address(this), liquidity); // Use transferFrom to set spender = msgSender()
        _burn(address(this), liquidity);  // Burn token
        _tokenA.transfer(msg.sender, amountA);
        _tokenB.transfer(msg.sender, amountB);
        updateReserves(reserveA - amountA, reserveB - amountB);

        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity); // Send removeLiquidity event
    }

    function getReserves() external view returns (uint256, uint256) {
        return (_reserveA, _reserveB);
    }

    function getTokenA() external view returns (address) {
        return address(_tokenA);
    }

    function getTokenB() external view returns (address) {
        return address(_tokenB);
    }

    function updateReserves(uint256 amountA, uint256 amountB) internal {
        _reserveA = amountA;
        _reserveB = amountB;
    }
}