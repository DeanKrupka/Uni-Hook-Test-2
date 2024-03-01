// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {FixedPointMathLib} from "../lib/solady/src/utils/FixedPointMathLib.sol"; 
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";

contract EulerInvariantHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;
    using CurrencyLibrary for Currency;
    
    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;

    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeRemoveLiquidityCount;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            noOp: false,
            accessLock: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------
        function getTokenInAmount(IPoolManager.SwapParams calldata params) public pure returns (uint256) {

        return 1e18;
    }

    /// @notice Calculate the amount of tokens sent to the swapper
    /// @param params SwapParams passed to the swap function
    /// @return The amount of tokens sent to the swapper
    function getTokenOutAmount(IPoolManager.SwapParams calldata params, Currency inputToken, Currency outputToken) public view returns (uint256) {
        uint256 inputAmount; 
        uint256 inputReserves = inputToken.balanceOfSelf();
        uint256 outputReserves = outputToken.balanceOfSelf();
        uint256 denominator = inputReserves + inputAmount;
        int256 numerator = FixedPointMathLib.expWad( 2 - (int256(inputReserves + inputAmount)));
        int256 product = int256(FixedPointMathLib.rawDiv(uint256(numerator), denominator));
        int256 output = -FixedPointMathLib.lambertW0Wad(product) - (int256(outputReserves));
        return uint256(output);
    }



    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4)
    {
                // determine inbound/outbound token based on 0->1 or 1->0 swap
        (Currency inbound, Currency outbound) =
            params.zeroForOne ? (key.currency0, key.currency1) : (key.currency1, key.currency0);

        // calculate the amount of tokens, based on a custom curve
        uint256 tokenInAmount = getTokenInAmount(params); // amount of tokens paid by the swapper
        uint256 tokenOutAmount = getTokenOutAmount(params, inbound, outbound); // amount of tokens sent to the swapper


        // inbound token is added to hook's reserves, debt paid by the swapper
        poolManager.take(inbound, address(this), tokenInAmount);

        // outbound token is removed from hook's reserves, and sent to the swapper
        outbound.transfer(address(poolManager), tokenOutAmount);
        poolManager.settle(outbound);

        // prevent normal v4 swap logic from executing
        return Hooks.NO_OP_SELECTOR;
    }

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4)
    {
        afterSwapCount[key.toId()]++;
        return BaseHook.afterSwap.selector;
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        beforeAddLiquidityCount[key.toId()]++;
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        beforeRemoveLiquidityCount[key.toId()]++;
        return BaseHook.beforeRemoveLiquidity.selector;
    }
}
