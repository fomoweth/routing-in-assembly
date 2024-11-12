// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

type Currency is address;

using {eq as ==, neq as !=, gt as >, gte as >=, lt as <, lte as <=} for Currency global;
using CurrencyLibrary for Currency global;

function eq(Currency x, Currency y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := eq(x, y)
	}
}

function neq(Currency x, Currency y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := xor(x, y)
	}
}

function gt(Currency x, Currency y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := gt(x, y)
	}
}

function gte(Currency x, Currency y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := iszero(lt(x, y))
	}
}

function lt(Currency x, Currency y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := lt(x, y)
	}
}

function lte(Currency x, Currency y) pure returns (bool z) {
	assembly ("memory-safe") {
		z := iszero(gt(x, y))
	}
}

/// @title CurrencyLibrary
/// @dev Modified from https://github.com/Uniswap/v4-core/blob/main/src/types/Currency.sol

library CurrencyLibrary {
	address internal constant NATIVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

	Currency internal constant NATIVE = Currency.wrap(NATIVE_ADDRESS);

	function approve(Currency currency, address spender, uint256 value) internal {
		assembly ("memory-safe") {
			if xor(currency, NATIVE_ADDRESS) {
				let ptr := mload(0x40)

				mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), spender)
				mstore(add(ptr, 0x24), value)

				if iszero(
					and(
						or(eq(mload(0x00), 0x01), iszero(returndatasize())),
						call(gas(), currency, 0x00, ptr, 0x44, 0x00, 0x20)
					)
				) {
					mstore(0x00, 0x3e3f8f73) // ApproveFailed()
					revert(0x1c, 0x04)
				}
			}
		}
	}

	function forceApprove(Currency currency, address spender, uint256 value) internal {
		assembly ("memory-safe") {
			if and(iszero(iszero(value)), xor(currency, NATIVE_ADDRESS)) {
				let ptr := mload(0x40)

				mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), spender)
				mstore(add(ptr, 0x24), value)

				if iszero(
					and(
						or(eq(mload(0x00), 0x01), iszero(returndatasize())),
						call(gas(), currency, 0x00, ptr, 0x44, 0x00, 0x20)
					)
				) {
					mstore(add(ptr, 0x24), 0x00)
					pop(call(gas(), currency, 0x00, ptr, 0x44, codesize(), 0x00))
					mstore(add(ptr, 0x24), value)

					if iszero(
						and(
							or(eq(mload(0x00), 0x01), iszero(returndatasize())),
							call(gas(), currency, 0x00, ptr, 0x44, 0x00, 0x20)
						)
					) {
						mstore(0x00, 0x3e3f8f73) // ApproveFailed()
						revert(0x1c, 0x04)
					}
				}
			}
		}
	}

	function transfer(Currency currency, address recipient, uint256 value) internal {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), recipient)
				mstore(add(ptr, 0x24), value)

				if iszero(
					and(
						or(eq(mload(0x00), 0x01), iszero(returndatasize())),
						call(gas(), currency, 0x00, ptr, 0x44, 0x00, 0x20)
					)
				) {
					mstore(0x00, 0x90b8ec18) // TransferFailed()
					revert(0x1c, 0x04)
				}
			}
			default {
				if iszero(call(gas(), recipient, value, 0x00, 0x00, 0x00, 0x00)) {
					mstore(0x00, 0xb06a467a) // TransferNativeFailed()
					revert(0x1c, 0x04)
				}
			}
		}
	}

	function transferFrom(Currency currency, address sender, address recipient, uint256 value) internal {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), sender)
				mstore(add(ptr, 0x24), recipient)
				mstore(add(ptr, 0x44), value)

				if iszero(
					and(
						or(eq(mload(0x00), 0x01), iszero(returndatasize())),
						call(gas(), currency, 0x00, ptr, 0x64, 0x00, 0x20)
					)
				) {
					mstore(0x00, 0x7939f424) // TransferFromFailed()
					revert(0x1c, 0x04)
				}
			}
			default {
				if or(lt(callvalue(), value), or(xor(sender, caller()), xor(recipient, address()))) {
					mstore(0x00, 0xa20c5180) // TransferFromNativeFailed()
					revert(0x1c, 0x04)
				}
			}
		}
	}

	function allowance(Currency currency, address owner, address spender) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0xdd62ed3e00000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), owner)
				mstore(add(ptr, 0x24), spender)

				if iszero(staticcall(gas(), currency, ptr, 0x44, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				value := mload(0x00)
			}
			default {
				value := not(0x00)
			}
		}
	}

	function balanceOf(Currency currency, address account) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), account)

				if iszero(staticcall(gas(), currency, ptr, 0x24, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				value := mload(0x00)
			}
			default {
				value := balance(account)
			}
		}
	}

	function balanceOfSelf(Currency currency) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
				mstore(add(ptr, 0x04), address())

				if iszero(staticcall(gas(), currency, ptr, 0x24, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				value := mload(0x00)
			}
			default {
				// 'selfbalance()' is cheaper than 'balance(address())'
				value := selfbalance()
			}
		}
	}

	function decimals(Currency currency) internal view returns (uint8 value) {
		assembly ("memory-safe") {
			switch eq(currency, NATIVE_ADDRESS)
			case 0x00 {
				let ptr := mload(0x40)

				mstore(ptr, 0x313ce56700000000000000000000000000000000000000000000000000000000)

				if iszero(staticcall(gas(), currency, ptr, 0x04, 0x00, 0x20)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				value := mload(0x00)
			}
			default {
				value := 18
			}
		}
	}

	function totalSupply(Currency currency) internal view returns (uint256 value) {
		assembly ("memory-safe") {
			if eq(currency, NATIVE_ADDRESS) {
				mstore(0x00, 0xf5993428) // InvalidCurrency()
				revert(0x1c, 0x04)
			}

			let ptr := mload(0x40)

			mstore(ptr, 0x18160ddd00000000000000000000000000000000000000000000000000000000)

			if iszero(staticcall(gas(), currency, ptr, 0x04, 0x00, 0x20)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			value := mload(0x00)
		}
	}

	function toId(Currency currency) internal pure returns (uint256) {
		return uint160(Currency.unwrap(currency));
	}

	function fromId(uint256 id) internal pure returns (Currency) {
		return Currency.wrap(address(uint160(id)));
	}

	function isNative(Currency currency) internal pure returns (bool b) {
		assembly ("memory-safe") {
			b := eq(currency, NATIVE_ADDRESS)
		}
	}

	function isZero(Currency currency) internal pure returns (bool b) {
		assembly ("memory-safe") {
			b := iszero(currency)
		}
	}
}
