// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Currency} from "src/types/Currency.sol";
import {Bytes32Cast} from "./Bytes32Cast.sol";

library Arrays {
	using Bytes32Cast for *;

	function reverse(bytes32[] memory input) internal pure returns (bytes32[] memory output) {
		uint256 length = input.length;
		output = new bytes32[](length);

		for (uint256 i; i < length; ++i) {
			output[i] = input[length - 1 - i];
		}
	}

	function reverse(bytes4[] memory input) internal pure returns (bytes4[] memory output) {
		bytes32[] memory reversed = reverse(input.castToBytes32Array());

		assembly ("memory-safe") {
			output := reversed
		}
	}

	function reverse(address[] memory input) internal pure returns (address[] memory output) {
		bytes32[] memory reversed = reverse(input.castToBytes32Array());

		assembly ("memory-safe") {
			output := reversed
		}
	}

	function reverse(Currency[] memory input) internal pure returns (Currency[] memory output) {
		bytes32[] memory reversed = reverse(input.castToBytes32Array());

		assembly ("memory-safe") {
			output := reversed
		}
	}

	function reverse(uint24[] memory input) internal pure returns (uint24[] memory output) {
		bytes32[] memory reversed = reverse(input.castToBytes32Array());

		assembly ("memory-safe") {
			output := reversed
		}
	}

	function reverse(uint256[] memory input) internal pure returns (uint256[] memory output) {
		bytes32[] memory reversed = reverse(input.castToBytes32Array());

		assembly ("memory-safe") {
			output := reversed
		}
	}
}
