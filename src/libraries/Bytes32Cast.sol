// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Currency} from "src/types/Currency.sol";

library Bytes32Cast {
	function castToBytes4(bytes32 input) internal pure returns (bytes4 output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes4Array(bytes32[] memory input) internal pure returns (bytes4[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32(bytes4 input) internal pure returns (bytes32 output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32Array(bytes4[] memory input) internal pure returns (bytes32[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToAddress(bytes32 input) internal pure returns (address output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToAddressArray(bytes32[] memory input) internal pure returns (address[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32(address input) internal pure returns (bytes32 output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32Array(address[] memory input) internal pure returns (bytes32[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToCurrency(bytes32 input) internal pure returns (Currency output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToCurrencyArray(bytes32[] memory input) internal pure returns (Currency[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32(Currency input) internal pure returns (bytes32 output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32Array(Currency[] memory input) internal pure returns (bytes32[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToUint24(bytes32 input) internal pure returns (uint24 output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToUint24Array(bytes32[] memory input) internal pure returns (uint24[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32(uint24 input) internal pure returns (bytes32 output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32Array(uint24[] memory input) internal pure returns (bytes32[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToUint256(bytes32 input) internal pure returns (uint256 output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToUint256Array(bytes32[] memory input) internal pure returns (uint256[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32(uint256 input) internal pure returns (bytes32 output) {
		assembly ("memory-safe") {
			output := input
		}
	}

	function castToBytes32Array(uint256[] memory input) internal pure returns (bytes32[] memory output) {
		assembly ("memory-safe") {
			output := input
		}
	}
}
