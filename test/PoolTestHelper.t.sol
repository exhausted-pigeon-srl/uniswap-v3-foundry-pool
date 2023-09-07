// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Test, console2} from "forge-std/Test.sol";
import {PoolTestHelper, IUniswapV3Pool, TickMath} from "../src/PoolTestHelper.sol";

contract CounterTest is Test {
    PoolTestHelper public helper;

    function setUp() public {
        helper = new PoolTestHelper();
    }

    function test_deployNewPool() public {
        address tokenA = makeAddr('tokenA');
        address tokenB = makeAddr('tokenB');

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
}
