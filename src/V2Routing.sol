// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IV2Routing} from "src/interfaces/IV2Routing.sol";
import {Constants} from "src/base/Constants.sol";
import {Currency} from "src/types/Currency.sol";

/// @title V2Routing

abstract contract V2Routing is IV2Routing, Constants {
	function swapExactTokensForTokens(
		Currency[] calldata path,
		address recipient,
		uint256 amountIn,
		uint256 amountOutMin,
		uint256 deadline
	) external payable returns (uint256 amountOut) {
		assembly ("memory-safe") {
			function require(condition, selector) {
				if iszero(condition) {
					mstore(0x00, selector)
					revert(0x1c, 0x04)
				}
			}

			function ternary(condition, x, y) -> z {
				z := xor(y, mul(xor(x, y), iszero(iszero(condition))))
			}

			function pairFor(ptr, token0, token1) -> pair {
				if gt(token0, token1) {
					let temp := token0
					token0 := token1
					token1 := temp
				}

				mstore(ptr, shl(0x60, token0))
				mstore(add(ptr, 0x14), shl(0x60, token1))

				let salt := keccak256(ptr, 0x28)

				mstore(ptr, add(hex"ff", shl(0x58, UNISWAP_V2_FACTORY)))
				mstore(add(ptr, 0x15), salt)
				mstore(add(ptr, 0x35), UNISWAP_V2_PAIR_INIT_CODE_HASH)

				pair := and(keccak256(ptr, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)

				// revert if the pair at computed address is not deployed yet
				require(iszero(iszero(extcodesize(pair))), 0x0022d46a) // PairNotExists()
			}

			function getReserves(ptr, pair, zeroForOne) -> reserveIn, reserveOut {
				// fetch the reserves of the pair; swap positions if necessary
				mstore(ptr, 0x0902f1ac00000000000000000000000000000000000000000000000000000000) // getReserves()

				if iszero(staticcall(gas(), pair, ptr, 0x04, ptr, 0x40)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				switch zeroForOne
				case 0x00 {
					reserveOut := mload(ptr)
					reserveIn := mload(add(ptr, 0x20))
				}
				default {
					reserveIn := mload(ptr)
					reserveOut := mload(add(ptr, 0x20))
				}

				require(and(iszero(iszero(reserveIn)), iszero(iszero(reserveOut))), 0x2f76b1d4) // InsuffcientReserves()
			}

			function swap(ptr, pair, zeroForOne, value, to) {
				// encode the calldata with swap parameters, then perform the swap
				mstore(ptr, 0x022c0d9f00000000000000000000000000000000000000000000000000000000) // swap(uint256,uint256,address,bytes)
				mstore(add(ptr, 0x04), mul(value, iszero(zeroForOne)))
				mstore(add(ptr, 0x24), mul(value, iszero(iszero(zeroForOne))))
				mstore(add(ptr, 0x44), to)
				mstore(add(ptr, 0x64), 0x80)

				if iszero(call(gas(), pair, 0x00, ptr, 0xa4, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}

			require(iszero(lt(deadline, timestamp())), 0x1ab7da6b) // DeadlineExpired()
			require(gt(path.length, 0x01), 0x20db8267) // InvalidPath()
			require(iszero(iszero(amountIn)), 0xdf5b2ee6) // InsufficientAmountIn()

			// get a free memory pointer, then allocate memory
			let ptr := mload(0x40)
			mstore(0x40, add(ptr, 0xc0))

			let lastIndex := sub(path.length, 0x01)
			let penultimateIndex := sub(lastIndex, 0x01)

			// retrieve the address of the input token
			let token := calldataload(path.offset)

			// compute the address of the first pair
			let pair := pairFor(ptr, token, calldataload(add(path.offset, 0x20)))

			// wrap ETH before the iteration if the caller is paying with ETH; otherwise, pay the first pair with the input token
			switch and(eq(token, WETH), iszero(lt(selfbalance(), amountIn)))
			case 0x00 {
				require(iszero(callvalue()), 0x21a64d90) // InvalidCallValue()

				mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000) // transferFrom(address,address,uint256)
				mstore(add(ptr, 0x04), caller())
				mstore(add(ptr, 0x24), pair)
				mstore(add(ptr, 0x44), amountIn)

				if iszero(
					and(
						or(eq(mload(0x00), 0x01), iszero(returndatasize())),
						call(gas(), token, 0x00, ptr, 0x64, 0x00, 0x20)
					)
				) {
					mstore(0x00, 0x7939f424) // TransferFromFailed()
					revert(0x1c, 0x04)
				}
			}
			default {
				mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000) // deposit()

				if iszero(call(gas(), WETH, amountIn, ptr, 0x04, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // transfer(address,uint256)
				mstore(add(ptr, 0x04), pair)
				mstore(add(ptr, 0x24), amountIn)

				if iszero(
					and(
						or(eq(mload(0x00), 0x01), iszero(returndatasize())),
						call(gas(), WETH, 0x00, ptr, 0x44, 0x00, 0x20)
					)
				) {
					mstore(0x00, 0x90b8ec18) // TransferFailed()
					revert(0x1c, 0x04)
				}
			}

			amountOut := amountIn

			// prettier-ignore
			// iterate over the path array, performing a swap for each pair
			for { let i } lt(i, lastIndex) { i := add(i, 0x01) } {
				let offset := add(path.offset, shl(0x05, i))

				let tokenIn := calldataload(offset)
				let tokenOut := calldataload(add(offset, 0x20))
				let zeroForOne := lt(tokenIn, tokenOut)

				let reserveIn, reserveOut := getReserves(ptr, pair, zeroForOne)

				// compute the amount of tokens to receive
				let numerator := mul(mul(amountOut, 997), reserveOut)
				let denominator := add(mul(reserveIn, 1000), mul(amountOut, 997))

				amountOut := div(numerator, denominator)

				switch eq(i, penultimateIndex)
				case 0x00 {
					let nextPair := pairFor(ptr, tokenOut, calldataload(add(offset, 0x40)))
					swap(ptr, pair, zeroForOne, amountOut, nextPair)
					pair := nextPair
				}
				default {
					swap(ptr, pair, zeroForOne, amountOut, recipient)
					break
				}
			}

			require(iszero(lt(amountOut, amountOutMin)), 0xe52970aa) // InsufficientAmountOut()
		}
	}

	function swapTokensForExactTokens(
		Currency[] calldata path,
		address recipient,
		uint256 amountOut,
		uint256 amountInMax,
		uint256 deadline
	) external payable returns (uint256 amountIn) {
		assembly ("memory-safe") {
			function require(condition, selector) {
				if iszero(condition) {
					mstore(0x00, selector)
					revert(0x1c, 0x04)
				}
			}

			function ternary(condition, x, y) -> z {
				z := xor(y, mul(xor(x, y), iszero(iszero(condition))))
			}

			function pairFor(ptr, token0, token1) -> pair {
				if gt(token0, token1) {
					let temp := token0
					token0 := token1
					token1 := temp
				}

				mstore(ptr, shl(0x60, token0))
				mstore(add(ptr, 0x14), shl(0x60, token1))

				let salt := keccak256(ptr, 0x28)

				mstore(ptr, add(hex"ff", shl(0x58, UNISWAP_V2_FACTORY)))
				mstore(add(ptr, 0x15), salt)
				mstore(add(ptr, 0x35), UNISWAP_V2_PAIR_INIT_CODE_HASH)

				pair := and(keccak256(ptr, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)

				// revert if the pair at computed address is not deployed yet
				require(iszero(iszero(extcodesize(pair))), 0x0022d46a) // PairNotExists()
			}

			function getReserves(ptr, pair, zeroForOne) -> reserveIn, reserveOut {
				// fetch the reserves of the pair; swap positions if necessary
				mstore(ptr, 0x0902f1ac00000000000000000000000000000000000000000000000000000000) // getReserves()

				if iszero(staticcall(gas(), pair, ptr, 0x04, ptr, 0x40)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				switch zeroForOne
				case 0x00 {
					reserveOut := mload(ptr)
					reserveIn := mload(add(ptr, 0x20))
				}
				default {
					reserveIn := mload(ptr)
					reserveOut := mload(add(ptr, 0x20))
				}

				require(and(iszero(iszero(reserveIn)), iszero(iszero(reserveOut))), 0x2f76b1d4) // InsuffcientReserves()
			}

			function swap(ptr, pair, zeroForOne, value, to) {
				// encode the calldata with swap parameters, then perform the swap
				mstore(ptr, 0x022c0d9f00000000000000000000000000000000000000000000000000000000) // swap(uint256,uint256,address,bytes)
				mstore(add(ptr, 0x04), mul(value, iszero(zeroForOne)))
				mstore(add(ptr, 0x24), mul(value, iszero(iszero(zeroForOne))))
				mstore(add(ptr, 0x44), to)
				mstore(add(ptr, 0x64), 0x80)

				if iszero(call(gas(), pair, 0x00, ptr, 0xa4, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}
			}

			require(iszero(lt(deadline, timestamp())), 0x1ab7da6b) // DeadlineExpired()
			require(gt(path.length, 0x01), 0x20db8267) // InvalidPath()
			require(iszero(iszero(amountInMax)), 0xdf5b2ee6) // InsufficientAmountIn()

			// get a free memory pointer, then allocate memory
			let ptr := mload(0x40)
			mstore(0x40, add(ptr, 0xc0))

			let lastIndex := sub(path.length, 0x01)
			let penultimateIndex := sub(lastIndex, 0x01)

			amountIn := amountOut

			// prettier-ignore
			// iterate over the path array, computing the delta amounts for each pair
			for { let i := lastIndex } gt(i, 0x00) { i := sub(i, 0x01) } {
				let offset := add(path.offset, shl(0x05, i))

				let tokenOut := calldataload(offset)
				let tokenIn := calldataload(sub(offset, 0x20))
				let pair := pairFor(ptr, tokenIn, tokenOut)
				let zeroForOne := lt(tokenIn, tokenOut)

				let reserveIn, reserveOut := getReserves(ptr, pair, zeroForOne)

				// compute the amount of tokens to pay to the pair
				let numerator := mul(mul(reserveIn, amountIn), 1000)
				let denominator := mul(sub(reserveOut, amountIn), 997)

				amountIn := add(div(numerator, denominator), 1)
			}

			require(iszero(gt(amountIn, amountInMax)), 0xdf5b2ee6) // InsufficientAmountIn()

			// retrieve the address of the input token
			let token := calldataload(path.offset)

			// compute the address of the first pair
			let pair := pairFor(ptr, token, calldataload(add(path.offset, 0x20)))

			// wrap ETH before the iteration if the caller is paying with ETH; otherwise, pay the first pair with the input token
			switch and(eq(token, WETH), iszero(lt(selfbalance(), amountIn)))
			case 0x00 {
				require(iszero(callvalue()), 0x21a64d90) // InvalidCallValue()

				mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000) // transferFrom(address,address,uint256)
				mstore(add(ptr, 0x04), caller())
				mstore(add(ptr, 0x24), pair)
				mstore(add(ptr, 0x44), amountIn)

				if iszero(
					and(
						or(eq(mload(0x00), 0x01), iszero(returndatasize())),
						call(gas(), token, 0x00, ptr, 0x64, 0x00, 0x20)
					)
				) {
					mstore(0x00, 0x7939f424) // TransferFromFailed()
					revert(0x1c, 0x04)
				}
			}
			default {
				mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000) // deposit()

				if iszero(call(gas(), WETH, amountIn, ptr, 0x04, 0x00, 0x00)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // transfer(address,uint256)
				mstore(add(ptr, 0x04), pair)
				mstore(add(ptr, 0x24), amountIn)

				if iszero(
					and(
						or(eq(mload(0x00), 0x01), iszero(returndatasize())),
						call(gas(), WETH, 0x00, ptr, 0x44, 0x00, 0x20)
					)
				) {
					mstore(0x00, 0x90b8ec18) // TransferFailed()
					revert(0x1c, 0x04)
				}
			}

			amountOut := amountIn

			// prettier-ignore
			// iterate over the path array, performing a swap for each pair
			for { let i } lt(i, lastIndex) { i := add(i, 0x01) } {
				let offset := add(path.offset, shl(0x05, i))

				let tokenIn := calldataload(offset)
				let tokenOut := calldataload(add(offset, 0x20))
				let zeroForOne := lt(tokenIn, tokenOut)

				let reserveIn, reserveOut := getReserves(ptr, pair, zeroForOne)

				// compute the amount of tokens to receive
				let numerator := mul(mul(amountOut, 997), reserveOut)
				let denominator := add(mul(reserveIn, 1000), mul(amountOut, 997))

				amountOut := div(numerator, denominator)

				switch eq(i, penultimateIndex)
				case 0x00 {
					let nextPair := pairFor(ptr, tokenOut, calldataload(add(offset, 0x40)))
					swap(ptr, pair, zeroForOne, amountOut, nextPair)
					pair := nextPair
				}
				default {
					swap(ptr, pair, zeroForOne, amountOut, recipient)
					break
				}
			}
		}
	}
}
