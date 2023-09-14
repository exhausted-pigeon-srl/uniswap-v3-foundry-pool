// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12; // 0.8.12 as fixed in UniswapV3Pool

import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-core/contracts/UniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";



contract PoolTestHelper is Test, IUniswapV3PoolDeployer {

    enum Chains { Mainnet, Goerli, Arbitrum, Optimism, Polygon, BSC, Celo, Base, Other }

    address internal factoryInit;
    address internal token0Init;
    address internal token1Init;
    uint24 internal feeInit;
    int24 internal tickSpacingInit;

    function createPool(address _tokenA, address _tokenB, uint24 _fee, uint160 _initialSqrtPriceX96, Chains _chain) public returns(IUniswapV3Pool _newPool) {
        // Avoid the cryptic R() error
        require(_initialSqrtPriceX96 >= TickMath.MIN_SQRT_RATIO, "initial sqrt price too low");
        require(_initialSqrtPriceX96 <= TickMath.MAX_SQRT_RATIO, "initial sqrt price too high");

        // Sort the tokens
        (token0Init, token1Init) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);

        // The factoryInit should correspond to the Uniswap V3 factoryInit, based on the _chain enum arg, if some create2 dependent logic is used
        if (uint256(_chain) <= uint256(Chains.Polygon)) {
            factoryInit = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
        } else if (_chain == Chains.BSC) {
            factoryInit = 0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7;
        } else if (_chain == Chains.Celo) {
            factoryInit = 0xAfE208a311B21f13EF87E33A90049fC17A7acDEc;
        } else if (_chain == Chains.Base) {
            factoryInit = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
        } else {
            factoryInit = address(this);
        }
        feeInit = _fee;

        // Assign the tick spacing based on the fees
        if (_fee == 100) {
            tickSpacingInit = 1;
        } else if (_fee == 500) {
            tickSpacingInit = 10;
        } else if (_fee == 3000) {
            tickSpacingInit = 60;
        } else if (_fee == 10000) {
            tickSpacingInit = 200;
        }

        // Deploy a new pool
        _newPool = new UniswapV3Pool{salt: keccak256(abi.encode(token0Init, token1Init, feeInit))}();

        // Initialise the pool
        _newPool.initialize(_initialSqrtPriceX96);
    }

    function parameters() public view returns (
        address,
        address,
        address,
        uint24,
        int24
    ) {
        return (
            factoryInit,
            token0Init,
            token1Init,
            feeInit,
            tickSpacingInit
        );
    }

    // Full range
    function addLiquidity(IUniswapV3Pool _pool, uint256 _amount0, uint256 _amount1) public returns(uint256 _liquidityAmount){
        int24 _tickSpacing = _pool.tickSpacing();
        int24 _lowerTick = TickMath.MIN_TICK;
        int24 _upperTick = TickMath.MAX_TICK;

        if(_lowerTick % _tickSpacing != 0) _lowerTick = _lowerTick + (_tickSpacing - (_lowerTick % _tickSpacing));

        if(_upperTick % _tickSpacing != 0) _upperTick = _upperTick - (_upperTick % _tickSpacing);

        return addLiquidity(
            _pool,
            _lowerTick,
            _upperTick,
            _amount0,
            _amount1
        );
    }

    // Given range
    function addLiquidity(IUniswapV3Pool _pool, int24 _lowerTick, int24 _upperTick, uint256 _amount0, uint256 _amount1) public returns(uint256){
        address _token0 = _pool.token0();
        address _token1 = _pool.token1();
        int24 _tickSpacing = _pool.tickSpacing();
        
        require(_lowerTick % _tickSpacing == 0, "lower tick not a multiple of tick spacing");
        require(_upperTick % _tickSpacing == 0, "upper tick not a multiple of tick spacing");

        (uint160 _currentSqrtPriceX96,,,,,,) = _pool.slot0();

        // compute the sqrt price at the lower and upper ticks
        uint160 _sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(_lowerTick);
        uint160 _sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(_upperTick);

        // compute the corresponding liquidity
        uint128 _liquidity = LiquidityAmounts.getLiquidityForAmounts(
            _currentSqrtPriceX96,
            _sqrtPriceAX96,
            _sqrtPriceBX96,
            _amount0,
            _amount1
        );

        _pool.mint(
            address(this),
            _lowerTick,
            _upperTick,
            _liquidity,
            abi.encode(_token0, _token1)
        );

        return _liquidity;
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) public {

        (address token0, address token1) = abi.decode(data, (address, address));

        if(amount0Owed > 0) {
            deal(token0, address(this), amount0Owed, true);
            IERC20(token0).transfer(msg.sender, amount0Owed);
        }
        
        if(amount1Owed > 0) {
            deal(token1, address(this), amount1Owed, true);
            IERC20(token1).transfer(msg.sender, amount1Owed);
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        uniswapV3MintCallback(
            amount0Delta > 0 ? uint256(amount0Delta) : 0,
            amount1Delta > 0 ? uint256(amount1Delta) : 0,
            data
        );
    }

    function swap(IUniswapV3Pool _pool, address _tokenIn, uint256 _amountIn) external {
        address _token0 = _pool.token0();
        address _token1 = _pool.token1();

        _pool.swap({
            recipient: msg.sender,
            zeroForOne: _tokenIn == _token0,
            amountSpecified: int256(_amountIn),
            sqrtPriceLimitX96: _tokenIn == _token0 ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            data: abi.encode(_token0, _token1)
        });
    }

    // remove liquidity
    function removeLiquidity(IUniswapV3Pool _pool, uint128 _amount, int24 _tickLower, int24 _tickUpper) public {
        int24 _tickSpacing = _pool.tickSpacing();
        
        require(_tickLower % _tickSpacing == 0, "lower tick not a multiple of tick spacing");
        require(_tickUpper % _tickSpacing == 0, "upper tick not a multiple of tick spacing");

        _pool.burn(_tickLower, _tickUpper, _amount);

        _pool.collect(msg.sender, TickMath.MIN_TICK, TickMath.MAX_TICK, type(uint128).max, type(uint128).max);
    }



    // increase cardinality

    // observe
}
