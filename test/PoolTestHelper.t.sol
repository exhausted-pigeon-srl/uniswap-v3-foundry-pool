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


contract PoolTestHelper_Test is Test, Events {
    PoolTestHelper public helper;

    IUniswapV3Pool pool;

    address tokenA;
    address tokenB;

    function setUp() public {
        helper = new PoolTestHelper();
        tokenA = address(new ERC20('A', 'A'));
        tokenB = address(new ERC20('B', 'B'));
    }

    function test_deployNewPool() public {
        uint256 _snap = vm.snapshot();

        pool = helper.createPool(
            tokenA,
            tokenB,
            100,
            TickMath.MIN_SQRT_RATIO + 1,
            PoolTestHelper.Chains.Mainnet
        );

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        assertEq(token0, pool.token0(), "The token0 does not match");
        assertEq(token1, pool.token1(), "The token1 does not match");
        assertEq(100, pool.fee(), "The fee does not match");
        assertEq(1, pool.tickSpacing(), "The tickSpacing does not match");

        (uint160 currentPrice,,,,,,) = pool.slot0();
        assertEq(TickMath.MIN_SQRT_RATIO + 1, currentPrice, "The current price does not match the initial price");
        
        // Use other order
        (tokenA, tokenB) = (tokenB, tokenA);
        
        vm.revertTo(_snap);

        IUniswapV3Pool pool2 = helper.createPool(
            tokenA,
            tokenB,
            100,
            TickMath.MIN_SQRT_RATIO + 1,
            PoolTestHelper.Chains.Mainnet
        );

        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        assertEq(token0, pool2.token0(), "The token0 does not match in the new pool");
        assertEq(token1, pool2.token1(), "The token1 does not match in the new pool");

        assertEq(address(pool), address(pool2), "The pools should be the same");
    }

    function test_addLiquidity_fullRange() public returns(uint256 _liquidityAmount){
        pool = helper.createPool(
            tokenA,
            tokenB,
            100,
            1 ether,
            PoolTestHelper.Chains.Mainnet
        );

        // Not matching the data (here, amount)
        vm.expectEmit(true, true, true, false, address(tokenA));
        emit Transfer(
            address(helper),
            address(pool),
            1e18
        );

        // Not matching the data (here, amount)
        vm.expectEmit(true, true, true, false, address(tokenB));
        emit Transfer(
            address(helper),
            address(pool),
            1e18
        );
    
        // Matching owner and ticks 
        vm.expectEmit(true, true, true, false, address(pool));
        emit Mint(
            address(helper),
            address(helper),
            -887272,
            887272,
            1e18,
            1e18,
            1e18
        );

        return helper.addLiquidity(pool, 10e18, 10e18);
    }

    function test_addLiquidity_concentrated() public {
        // Fee 500 -> tick spacing 10
        int24 _lowerTick = 1000;
        int24 _upperTick = _lowerTick + 10;

        pool = helper.createPool(
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
            address(pool),
            1e18
        );

        // Not matching the data (here, amount)
        vm.expectEmit(true, true, false, false, address(tokenB));
        emit Transfer(
            address(helper),
            address(pool),
            1e18
        );
    
        // Matching owner and ticks 
        vm.expectEmit(true, true, true, false, address(pool));
        emit Mint(
            address(helper),
            address(helper),
            _lowerTick,
            _upperTick,
            1e18,
            1e18,
            1e18
        );

        helper.addLiquidity(pool, _lowerTick, _upperTick, 1e18, 1e18);
    }

    // swap
    function test_swap() public {
        test_addLiquidity_fullRange();

        vm.deal(tokenA, 1 ether);

        // Match the addresses
        vm.expectEmit(true, true, false, false, address(tokenA));
        emit Transfer(address(helper), address(pool), 1e18);

        vm.expectEmit(true, true, false, false, address(pool));
        emit Swap(address(helper), address(this), 0, 0, 0, 0, 0);

        helper.swap(pool, tokenA, 1 ether);
    }

    // remove liquidity
    function test_removeLiquidity_fullRange() public {
        test_addLiquidity_fullRange();

        helper.removeLiquidity(pool, 0.5 ether, TickMath.MIN_TICK, TickMath.MAX_TICK);
    }



    // increase cardinality (or max in setup)

    // observe
}