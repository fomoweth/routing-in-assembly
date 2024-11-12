// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Currency} from "src/types/Currency.sol";

/// @title CurrencyNamer
/// @dev Modified from https://github.com/Uniswap/v3-periphery/blob/0.8/contracts/libraries/SafeERC20Namer.sol

library CurrencyNamer {
	function symbol(Currency currency) internal view returns (string memory) {
		string memory res = callAndParseStringReturn(currency, 0x95d89b41);

		if (bytes(res).length == 0) {
			return toAsciiString(Currency.unwrap(currency), 8);
		}

		return res;
	}

	function name(Currency currency) internal view returns (string memory) {
		string memory res = callAndParseStringReturn(currency, 0x06fdde03);

		if (bytes(res).length == 0) {
			return toAsciiString(Currency.unwrap(currency), 40);
		}

		return res;
	}

	function callAndParseStringReturn(Currency currency, bytes4 selector) private view returns (string memory) {
		(bool success, bytes memory returndata) = Currency.unwrap(currency).staticcall(
			abi.encodeWithSelector(selector)
		);

		if (success && returndata.length != 0) {
			if (returndata.length == 32) {
				return bytes32ToString(abi.decode(returndata, (bytes32)));
			} else if (returndata.length > 64) {
				return abi.decode(returndata, (string));
			}
		}

		return "";
	}

	function bytes32ToString(bytes32 x) private pure returns (string memory) {
		bytes memory buffer = new bytes(32);
		uint256 count;

		unchecked {
			for (uint256 j; j < 32; ++j) {
				bytes1 c = x[j];

				if (c != 0) {
					buffer[count] = c;
					++count;
				}
			}
		}

		bytes memory trimmed = new bytes(count);

		for (uint256 j; j < count; ) {
			trimmed[j] = buffer[j];

			unchecked {
				++j;
			}
		}

		return string(trimmed);
	}

	function toAsciiString(address target, uint256 length) internal pure returns (string memory) {
		unchecked {
			require(length % 2 == 0 && length > 0 && length <= 40);

			uint256 uTarget = uint160(target);
			bytes memory buffer = new bytes(length);
			uint256 len = length / 2;

			for (uint256 i; i < len; ++i) {
				uint8 b = uint8(uTarget >> (8 * (19 - i)));
				uint8 hi = b >> 4;
				uint8 lo = b - (hi << 4);

				buffer[2 * i] = char(hi);
				buffer[2 * i + 1] = char(lo);
			}

			return string(buffer);
		}
	}

	function char(uint8 b) private pure returns (bytes1 c) {
		return bytes1(b + b < 10 ? 0x30 : 0x37);
	}
}
