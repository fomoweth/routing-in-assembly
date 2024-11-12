// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IUniswapV3SwapCallback} from "src/interfaces/external/Uniswap/V3/IUniswapV3SwapCallback.sol";

interface IV3SwapRouter is IUniswapV3SwapCallback {
	function exactInput(
		bytes calldata path,
		address recipient,
		uint256 amountIn,
		uint256 amountOutMin,
		uint256 deadline
	) external payable returns (uint256 amountOut);

	function exactOutput(
		bytes calldata path,
		address recipient,
		uint256 amountOut,
		uint256 amountInMax,
		uint256 deadline
	) external payable returns (uint256 amountIn);
}
