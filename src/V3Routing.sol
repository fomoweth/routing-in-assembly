// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IV3Routing} from "src/interfaces/IV3Routing.sol";
import {Constants} from "src/base/Constants.sol";

/// @title V3SwapRouter

abstract contract V3Routing is IV3Routing, Constants {
	function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
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

			function decodePool(offset) -> tokenIn, tokenOut, fee {
				let firstWord := calldataload(offset)

				tokenIn := shr(0x60, firstWord)
				fee := and(shr(0x48, firstWord), 0xffffff)
				tokenOut := shr(0x60, calldataload(add(offset, NEXT_OFFSET)))
			}

			function getPool(ptr, token0, token1, fee) -> pool {
				// sort tokens if necessary
				if gt(token0, token1) {
					let temp := token0
					token0 := token1
					token1 := temp
				}

				// store the addresses of token0, token1, and fee to compute the salt of the pool
				mstore(add(ptr, 0x15), token0)
				mstore(add(ptr, 0x35), token1)
				mstore(add(ptr, 0x55), fee)

				// store the address of the factory, computed salt, and the init code hash of the pool
				mstore(ptr, add(hex"ff", shl(0x58, UNISWAP_V3_FACTORY)))
				mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x60))
				mstore(add(ptr, 0x35), UNISWAP_V3_POOL_INIT_CODE_HASH)

				pool := and(keccak256(ptr, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)

				// revert if the pool at computed address is not deployed yet
				require(iszero(iszero(extcodesize(pool))), 0x0ba98f1c) // PoolNotExists()
			}

			function pay(ptr, token, payer, amount) {
				switch and(eq(token, WETH), iszero(lt(selfbalance(), amount)))
				case 0x01 {
					// wrap ETH into WETH, then pay the pool
					mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000) // deposit()

					if iszero(call(gas(), WETH, amount, ptr, 0x04, 0x00, 0x00)) {
						returndatacopy(ptr, 0x00, returndatasize())
						revert(ptr, returndatasize())
					}

					mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // transfer(address,uint256)
					mstore(add(ptr, 0x04), caller())
					mstore(add(ptr, 0x24), amount)

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
				default {
					switch eq(payer, address())
					case 0x00 {
						mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000) // transferFrom(address,address,uint256)
						mstore(add(ptr, 0x04), payer)
						mstore(add(ptr, 0x24), caller())
						mstore(add(ptr, 0x44), amount)

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
						mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // transfer(address,uint256)
						mstore(add(ptr, 0x04), caller())
						mstore(add(ptr, 0x24), amount)

						if iszero(
							and(
								or(eq(mload(0x00), 0x01), iszero(returndatasize())),
								call(gas(), token, 0x00, ptr, 0x44, 0x00, 0x20)
							)
						) {
							mstore(0x00, 0x90b8ec18) // TransferFailed()
							revert(0x1c, 0x04)
						}
					}
				}
			}

			require(or(sgt(amount0Delta, 0x00), sgt(amount1Delta, 0x00)), 0x11157667) // InvalidSwap()

			// decode the address of the payer from the data
			let payerOffset := calldataload(add(data.offset, calldataload(data.offset)))
			let payer := and(calldataload(add(data.offset, payerOffset)), 0xffffffffffffffffffffffffffffffffffffffff)
			require(iszero(iszero(payer)), 0x8eb5b891) // InvalidPayer()

			// extract the path for the swap from the data
			let pathLength := calldataload(add(data.offset, add(payerOffset, 0x20)))
			let pathOffset := add(data.offset, add(payerOffset, 0x40))

			// decode the salt of the first pool from the path
			let tokenIn, tokenOut, fee := decodePool(pathOffset)

			// determine the direction of the current swap and amount of tokens to be paid to the pool
			let isExactInput
			let amountToPay

			switch sgt(amount0Delta, 0x00)
			case 0x00 {
				isExactInput := lt(tokenOut, tokenIn)
				amountToPay := amount1Delta
			}
			default {
				isExactInput := lt(tokenIn, tokenOut)
				amountToPay := amount0Delta
			}

			// get a free memory pointer
			let ptr := mload(0x40)

			// compute the address of the first pool
			let pool := getPool(ptr, tokenIn, tokenOut, fee)
			require(eq(pool, caller()), 0x2083cd40) // InvalidPool()

			switch iszero(isExactInput)
			case 0x00 {
				// pay the pool
				pay(ptr, tokenIn, payer, amountToPay)
			}
			default {
				switch lt(pathLength, MULTIPLE_POOLS_MIN_LENGTH)
				case 0x00 {
					// update the path by slicing out the first token and fee for the next iteration
					pathOffset := add(pathOffset, NEXT_OFFSET)
					pathLength := sub(pathLength, NEXT_OFFSET)

					// determine the full length of the path, padded with zeros to the right
					let pathSize := add(pathLength, sub(0x20, mod(pathLength, 0x20)))

					// decode the salt of the next pool from the path
					tokenOut, tokenIn, fee := decodePool(pathOffset)
					let zeroForOne := lt(tokenIn, tokenOut)

					// compute the address of the next pool
					pool := getPool(ptr, tokenIn, tokenOut, fee)

					// encode the calldata with swap parameters, then perform the swap
					mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000) // swap(address,bool,int256,uint160,bytes)
					mstore(add(ptr, 0x04), caller())
					mstore(add(ptr, 0x24), zeroForOne)
					mstore(add(ptr, 0x44), not(sub(amountToPay, 0x01)))
					mstore(add(ptr, 0x64), ternary(zeroForOne, MIN_SQRT_PRICE_LIMIT, MAX_SQRT_PRICE_LIMIT))
					mstore(add(ptr, 0x84), 0xa0)
					mstore(add(ptr, 0xa4), shl(0x05, add(div(pathSize, 0x20), 0x04)))
					mstore(add(ptr, 0xc4), 0x20)
					mstore(add(ptr, 0xe4), 0x40)
					mstore(add(ptr, 0x104), payer)
					mstore(add(ptr, 0x124), pathLength)
					calldatacopy(add(ptr, 0x144), pathOffset, pathSize)

					if iszero(call(gas(), pool, 0x00, ptr, add(0x144, pathSize), 0x00, 0x40)) {
						returndatacopy(ptr, 0x00, returndatasize())
						revert(ptr, returndatasize())
					}
				}
				default {
					// pay the pool; because exact output swaps are executed in reverse order, tokenOut is actually tokenIn
					pay(ptr, tokenOut, payer, amountToPay)

					// cache amount of tokens paid to the pool
					sstore(AMOUNT_IN_CACHED_SLOT, amountToPay)
				}
			}
		}
	}

	function exactInput(
		bytes calldata path,
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

			function decodePool(offset) -> tokenIn, tokenOut, fee {
				let firstWord := calldataload(offset)
				tokenIn := shr(0x60, firstWord)
				fee := and(shr(0x48, firstWord), 0xffffff)
				tokenOut := shr(0x60, calldataload(add(offset, NEXT_OFFSET)))
			}

			function getPool(ptr, token0, token1, fee) -> pool {
				// sort tokens if necessary
				if gt(token0, token1) {
					let temp := token0
					token0 := token1
					token1 := temp
				}

				// store the addresses of token0, token1, and fee to compute the salt of the pool
				mstore(add(ptr, 0x15), token0)
				mstore(add(ptr, 0x35), token1)
				mstore(add(ptr, 0x55), fee)

				// store the address of the factory, computed salt, and the init code hash of the pool
				mstore(ptr, add(hex"ff", shl(0x58, UNISWAP_V3_FACTORY)))
				mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x60))
				mstore(add(ptr, 0x35), UNISWAP_V3_POOL_INIT_CODE_HASH)

				pool := and(keccak256(ptr, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)

				// revert if the pool at computed address is not deployed yet
				require(iszero(iszero(extcodesize(pool))), 0x0ba98f1c) // PoolNotExists()
			}

			require(iszero(lt(deadline, timestamp())), 0x1ab7da6b) // DeadlineExpired()
			require(iszero(mod(sub(path.length, ADDR_SIZE), NEXT_OFFSET)), 0x20db8267) // InvalidPath()
			require(iszero(iszero(amountIn)), 0xdf5b2ee6) // InsufficientAmountIn()

			// the caller pays for the first hop
			let payer := caller()

			// get a free memory pointer, then allocate memory
			let ptr := mload(0x40)
			mstore(0x40, add(ptr, 0x184))

			// prettier-ignore
			for { } 0x01 { } {
				// determine whether the path includes multiple pools
				let hasMultiplePools := iszero(lt(path.length, MULTIPLE_POOLS_MIN_LENGTH))

				// decode the salt of the current pool from the path
				let tokenIn, tokenOut, fee := decodePool(path.offset)
				let zeroForOne := lt(tokenIn, tokenOut)

				// compute the address of the current pool
				let pool := getPool(ptr, tokenIn, tokenOut, fee)

				// encode the calldata with swap parameters, then perform the swap;
				// some parameters can be set with constant values, as exact input swaps only require the first pool in the path
				mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000) // swap(address,bool,int256,uint160,bytes)
				mstore(add(ptr, 0x04), ternary(hasMultiplePools, address(), recipient))
				mstore(add(ptr, 0x24), zeroForOne)
				mstore(add(ptr, 0x44), amountIn)
				mstore(add(ptr, 0x64), ternary(zeroForOne, MIN_SQRT_PRICE_LIMIT, MAX_SQRT_PRICE_LIMIT))
				mstore(add(ptr, 0x84), 0xa0)
				mstore(add(ptr, 0xa4), 0xc0)
				mstore(add(ptr, 0xc4), 0x20)
				mstore(add(ptr, 0xe4), 0x40)
				mstore(add(ptr, 0x104), payer)
				mstore(add(ptr, 0x124), POP_OFFSET) // only the first pool is required
				calldatacopy(add(ptr, 0x144), path.offset, 0x40)

				if iszero(call(gas(), pool, 0x00, ptr, 0x184, 0x00, 0x40)) {
					returndatacopy(ptr, 0x00, returndatasize())
					revert(ptr, returndatasize())
				}

				amountIn := add(not(ternary(zeroForOne, mload(0x20), mload(0x00))), 0x01)

				switch iszero(hasMultiplePools)
				case 0x00 {
					// update the address of the payer if it is not assigned to the address of this contract;
					// the caller has made the payment at this point
					if xor(payer, address()) {
						payer := address()
					}

					// update the path by slicing out the first token and fee for the next iteration
					path.offset := add(path.offset, NEXT_OFFSET)
					path.length := sub(path.length, NEXT_OFFSET)
				}
				default {
					amountOut := amountIn
					break
				}
			}

			require(iszero(lt(amountOut, amountOutMin)), 0xe52970aa) // InsufficientAmountOut()
		}
	}

	function exactOutput(
		bytes calldata path,
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

			function decodePool(offset) -> tokenOut, tokenIn, fee {
				let firstWord := calldataload(offset)
				tokenOut := shr(0x60, firstWord) //
				fee := and(shr(0x48, firstWord), 0xffffff)
				tokenIn := shr(0x60, calldataload(add(offset, NEXT_OFFSET)))
			}

			function getPool(ptr, token0, token1, fee) -> pool {
				// sort tokens if necessary
				if gt(token0, token1) {
					let temp := token0
					token0 := token1
					token1 := temp
				}

				// store the addresses of token0, token1, and fee to compute the salt of the pool
				mstore(add(ptr, 0x15), token0)
				mstore(add(ptr, 0x35), token1)
				mstore(add(ptr, 0x55), fee)

				// store the address of the factory, computed salt, and the init code hash of the pool
				mstore(ptr, add(hex"ff", shl(0x58, UNISWAP_V3_FACTORY)))
				mstore(add(ptr, 0x15), keccak256(add(ptr, 0x15), 0x60))
				mstore(add(ptr, 0x35), UNISWAP_V3_POOL_INIT_CODE_HASH)

				pool := and(keccak256(ptr, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)

				// revert if the pool at computed address is not deployed yet
				require(iszero(iszero(extcodesize(pool))), 0x0ba98f1c) // PoolNotExists()
			}

			require(iszero(lt(deadline, timestamp())), 0x1ab7da6b) // DeadlineExpired()
			require(iszero(mod(sub(path.length, ADDR_SIZE), NEXT_OFFSET)), 0x20db8267) // InvalidPath()
			require(iszero(iszero(amountInMax)), 0xdf5b2ee6) // InsufficientAmountIn()

			// determine the full length of the path, padded with zeros to the right
			let pathSize := add(path.length, sub(0x20, mod(path.length, 0x20)))

			// get a free memory pointer, then allocate memory
			let ptr := mload(0x40)
			mstore(0x40, add(ptr, add(0x144, pathSize)))

			// decode the salt of the first pool from the path
			let tokenOut, tokenIn, fee := decodePool(path.offset)
			let zeroForOne := lt(tokenIn, tokenOut)

			// compute the address of the pool
			let pool := getPool(ptr, tokenIn, tokenOut, fee)

			// encode the calldata with swap parameters, then execute the swap
			mstore(ptr, 0x128acb0800000000000000000000000000000000000000000000000000000000) // swap(address,bool,int256,uint160,bytes)
			mstore(add(ptr, 0x04), recipient)
			mstore(add(ptr, 0x24), zeroForOne)
			mstore(add(ptr, 0x44), not(sub(amountOut, 0x01)))
			mstore(add(ptr, 0x64), ternary(zeroForOne, MIN_SQRT_PRICE_LIMIT, MAX_SQRT_PRICE_LIMIT))
			mstore(add(ptr, 0x84), 0xa0)
			mstore(add(ptr, 0xa4), shl(0x05, add(div(pathSize, 0x20), 0x04)))
			mstore(add(ptr, 0xc4), 0x20)
			mstore(add(ptr, 0xe4), 0x40)
			mstore(add(ptr, 0x104), caller())
			mstore(add(ptr, 0x124), path.length)
			calldatacopy(add(ptr, 0x144), path.offset, pathSize)

			if iszero(call(gas(), pool, 0x00, ptr, add(0x144, pathSize), 0x00, 0x40)) {
				returndatacopy(ptr, 0x00, returndatasize())
				revert(ptr, returndatasize())
			}

			// validate that the amount of tokens received is equal to the specified amount out
			let amountOutReceived := add(not(ternary(zeroForOne, mload(0x20), mload(0x00))), 0x01)
			require(eq(amountOutReceived, amountOut), 0xe52970aa) // InsufficientAmountOut()

			// retrieve the cached amount in from the slot, then validate that it does not exceed the maximum limit
			amountIn := sload(AMOUNT_IN_CACHED_SLOT)
			require(iszero(gt(amountIn, amountInMax)), 0xdf5b2ee6) // InsufficientAmountIn()

			// reset the cached amount in to the default value
			sstore(AMOUNT_IN_CACHED_SLOT, sub(shl(256, 1), 1))
		}
	}
}
