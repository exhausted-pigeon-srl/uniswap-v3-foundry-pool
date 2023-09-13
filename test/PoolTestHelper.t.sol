// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IUniswapV3PoolEvents} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolEvents.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import {Test, console2} from "forge-std/Test.sol";
import {PoolTestHelper, IUniswapV3Pool, TickMath} from "../src/PoolTestHelper.sol";

contract Events is IUniswapV3PoolEvents {
    // IERC20:
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

}


contract CounterTest is Test, Events {
    PoolTestHelper public helper;

    address tokenA;
    address tokenB;

    function setUp() public {
        helper = new PoolTestHelper();
        tokenA = address(new ERC20('A', 'A'));
        tokenB = address(new ERC20('B', 'B'));
    }

    function test_deployNewPool() public {
        uint256 _snap = vm.snapshot();

        IUniswapV3Pool _newPool = helper.createPool(
            tokenA,
            tokenB,
            100,
            TickMath.MIN_SQRT_RATIO + 1,
            PoolTestHelper.Chains.Mainnet
        );

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        assertEq(token0, _newPool.token0(), "The token0 does not match");
        assertEq(token1, _newPool.token1(), "The token1 does not match");
        assertEq(100, _newPool.fee(), "The fee does not match");
        assertEq(1, _newPool.tickSpacing(), "The tickSpacing does not match");

        (uint160 currentPrice,,,,,,) = _newPool.slot0();
        assertEq(TickMath.MIN_SQRT_RATIO + 1, currentPrice, "The current price does not match the initial price");
        
        // Use other order
        (tokenA, tokenB) = (tokenB, tokenA);
        
        vm.revertTo(_snap);

        IUniswapV3Pool _newPool2 = helper.createPool(
            tokenA,
            tokenB,
            100,
            TickMath.MIN_SQRT_RATIO + 1,
            PoolTestHelper.Chains.Mainnet
        );

        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        assertEq(token0, _newPool2.token0(), "The token0 does not match in the new pool");
        assertEq(token1, _newPool2.token1(), "The token1 does not match in the new pool");

        assertEq(address(_newPool), address(_newPool2), "The pools should be the same");
    }

    function test_addLiquidity_fullRange() public {
        IUniswapV3Pool _newPool = helper.createPool(
            tokenA,
            tokenB,
            100,
            10 ether,
            PoolTestHelper.Chains.Mainnet
        );

        // Not matching the data (here, amount)
        vm.expectEmit(true, true, true, false, address(tokenA));
        emit Transfer(
            address(helper),
            address(_newPool),
            1e18
        );

        // Not matching the data (here, amount)
        vm.expectEmit(true, true, true, false, address(tokenB));
        emit Transfer(
            address(helper),
            address(_newPool),
            1e18
        );
    
        // Matching owner and ticks 
        vm.expectEmit(true, true, true, false, address(_newPool));
        emit Mint(
            address(helper),
            address(helper),
            -887272,
            887272,
            1e18,
            1e18,
            1e18
        );

        helper.addLiquidity(_newPool, 1e18, 1e18);
    }

    function test_addLiquidity_concentrated() public {
        // Fee 500 -> tick spacing 10
        int24 _lowerTick = 1000;
        int24 _upperTick = _lowerTick + 10;

        IUniswapV3Pool _newPool = helper.createPool(
            tokenA,
            tokenB,
            500,
            TickMath.getSqrtRatioAtTick(_lowerTick + 5),
            PoolTestHelper.Chains.Mainnet
        );

        // Not matching the data (here, amount)
        vm.expectEmit(true, true, false, false, address(tokenA));
        emit Transfer(
            address(helper),
            address(_newPool),
            1e18
        );

        // Not matching the data (here, amount)
        vm.expectEmit(true, true, false, false, address(tokenB));
        emit Transfer(
            address(helper),
            address(_newPool),
            1e18
        );
    
        // Matching owner and ticks 
        vm.expectEmit(true, true, true, false, address(_newPool));
        emit Mint(
            address(helper),
            address(helper),
            _lowerTick,
            _upperTick,
            1e18,
            1e18,
            1e18
        );

        helper.addLiquidity(_newPool, _lowerTick, _upperTick, 1e18, 1e18);
    }

    // swap 

    // remove liquidirty

    // increase cardinality (or max in setup)

    // observe
}