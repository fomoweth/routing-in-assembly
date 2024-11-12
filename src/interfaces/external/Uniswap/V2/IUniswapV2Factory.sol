// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Currency} from "src/types/Currency.sol";

interface IUniswapV2Factory {
	event PairCreated(Currency indexed currency0, Currency indexed currency1, address pair, uint);

	function feeTo() external view returns (address);

	function feeToSetter() external view returns (address);

	function getPair(Currency currencyA, Currency currencyB) external view returns (address pair);

	function allPairs(uint256 index) external view returns (address pair);

	function allPairsLength() external view returns (uint256);

	function createPair(Currency currencyA, Currency currencyB) external returns (address pair);

	function setFeeTo(address feeTo) external;

	function setFeeToSetter(address feeToSetter) external;
}
