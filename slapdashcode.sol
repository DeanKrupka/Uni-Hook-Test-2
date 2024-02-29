    /// @notice Calculate the amount of tokens sent to the swapper
    /// @param params SwapParams passed to the swap function
    /// @return The amount of tokens sent to the swapper
    function getTokenOutAmount(IPoolManager.SwapParams calldata params) public pure returns (uint256) {
        uint256 inputAmount;
        uint256 inputReserves = IERC20(inputToken0).balanceOf(address(this));
        uint256 output = Solady.W_function(inputAmount.exp() - inputReserves);
        return output;
    }

function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4)
    {
        // calculate the amount of tokens, based on a custom curve
        uint256 tokenInAmount = params.amountSpecified; // assume its exact-input swap
        uint256 tokenOutAmount = getTokenOutAmount(params); // amount of tokens sent to the swapper

        // determine inbound/outbound token based on 0->1 or 1->0 swap
        (Currency inbound, Currency outbound) =
            params.zeroForOne ? (key.currency0, key.currency1) : (key.currency1, key.currency0);

        // inbound token is added to hook's reserves, debt paid by the swapper
        poolManager.take(inbound, address(this), tokenInAmount);

        // outbound token is removed from hook's reserves, and sent to the swapper
        outbound.transfer(address(poolManager), tokenOutAmount);
        poolManager.settle(outbound);

        // prevent normal v4 swap logic from executing
        return Hooks.NO_OP_SELECTOR;
    }