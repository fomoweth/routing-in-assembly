// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IV2SwapRouter {
	function swapExactTokensForTokens(
		address[] calldata path,
		address recipient,
		uint256 amountIn,
		uint256 amountOutMin,
		uint256 deadline
	) external payable returns (uint256 amount);

	function swapTokensForExactTokens(
		address[] calldata path,
		address recipient,
		uint256 amountOut,
		uint256 amountInMax,
		uint256 deadline
	) external payable returns (uint256 amount);
}
