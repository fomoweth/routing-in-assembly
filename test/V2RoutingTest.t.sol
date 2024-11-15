// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IUniswapV2Pair} from "src/interfaces/external/Uniswap/V2/IUniswapV2Pair.sol";
import {Currency} from "src/types/Currency.sol";
import {BaseTest} from "./BaseTest.t.sol";

contract V2RoutingTest is BaseTest {
	address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

	bytes32 constant UNISWAP_V2_PAIR_INIT_CODE_HASH =
		0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

	function setUp() public virtual override {
		super.setUp();
		setPairs();
	}

	function test_swapExactTokensForTokensForSingleHop() public virtual {
		performTrades(getCurrencies(WETH, USDC), 10 ether, true);
	}

	function test_swapExactTokensForTokensFor2Hops() public virtual {
		performTrades(getCurrencies(WETH, WBTC, USDC), 10 ether, true);
	}

	function test_swapExactTokensForTokensFor3Hops() public virtual {
		performTrades(getCurrencies(WETH, WBTC, USDC, DAI), 10 ether, true);
	}

	function test_swapTokensForExactTokensForSingleHop() public virtual {
		performTrades(getCurrencies(WETH, USDC), 10000 * (1e6), false);
	}

	function test_swapTokensForExactTokensFor2Hops() public virtual {
		performTrades(getCurrencies(WETH, WBTC, USDC), 10000 * (1e6), false);
	}

	function test_swapTokensForExactTokensFor3Hops() public virtual {
		performTrades(getCurrencies(WETH, WBTC, USDC, DAI), 10000 ether, false);
	}

	function performTrades(
		Currency[] memory path,
		uint256 amount,
		bool isExactInput
	) internal virtual returns (uint256 amountIn, uint256 amountOut) {
		Currency currencyIn = path[0];
		Currency currencyOut = path[path.length - 1];

		uint256[] memory amounts = isExactInput ? getAmountsOut(path, amount) : getAmountsIn(path, amount);
		amountIn = amounts[0];
		amountOut = amounts[path.length - 1];

		deal(currencyIn, SENDER, amounts[0]);

		uint256 balanceIn = currencyIn.balanceOf(SENDER);
		uint256 balanceOut = currencyOut.balanceOf(RECIPIENT);

		vm.prank(SENDER);

		if (isExactInput) {
			amountOut = routing.swapExactTokensForTokens(path, RECIPIENT, amountIn, amountOut, DEADLINE);
		} else {
			amountIn = routing.swapTokensForExactTokens(path, RECIPIENT, amountOut, amountIn, DEADLINE);
		}

		assertEq(currencyIn.balanceOf(SENDER), balanceIn - amountIn, "INSUFFICIENT_BALANCE_IN");
		assertGe(currencyOut.balanceOf(RECIPIENT), balanceOut + amountOut, "INSUFFICIENT_BALANCE_OUT");
	}

	function getAmountsOut(
		Currency[] memory path,
		uint256 amountIn
	) internal view virtual returns (uint256[] memory amounts) {
		uint256 length = path.length;
		assertTrue(length > 1, "INVALID_PATH");

		amounts = new uint256[](length);
		amounts[0] = amountIn;

		for (uint256 i; i < length - 1; ++i) {
			(uint256 reserveIn, uint256 reserveOut) = getReserves(path[i], path[i + 1]);
			amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
		}
	}

	function getAmountsIn(
		Currency[] memory path,
		uint256 amountOut
	) internal view virtual returns (uint256[] memory amounts) {
		uint256 length = path.length;
		assertTrue(length > 1, "INVALID_PATH");

		amounts = new uint256[](path.length);
		amounts[amounts.length - 1] = amountOut;

		for (uint256 i = path.length - 1; i > 0; --i) {
			(uint256 reserveIn, uint256 reserveOut) = getReserves(path[i - 1], path[i]);
			amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
		}
	}

	function getAmountOut(
		uint256 amountIn,
		uint256 reserveIn,
		uint256 reserveOut
	) internal pure virtual returns (uint256 amountOut) {
		assertTrue(amountIn != 0, "INSUFFICIENT_INPUT_AMOUNT");
		assertTrue(reserveIn != 0 && reserveOut != 0, "INSUFFICIENT_LIQUIDITY");

		uint256 amountInWithFee = amountIn * 997;
		uint256 numerator = amountInWithFee * (reserveOut);
		uint256 denominator = reserveIn * 1000 + (amountInWithFee);
		amountOut = numerator / denominator;
	}

	function getAmountIn(
		uint256 amountOut,
		uint256 reserveIn,
		uint256 reserveOut
	) internal pure virtual returns (uint256 amountIn) {
		assertTrue(amountOut != 0, "INSUFFICIENT_OUTPUT_AMOUNT");
		assertTrue(reserveIn != 0 && reserveOut != 0, "INSUFFICIENT_LIQUIDITY");

		uint256 numerator = reserveIn * amountOut * 1000;
		uint256 denominator = (reserveOut - amountOut) * 997;
		amountIn = (numerator / denominator) + 1;
	}

	function getReserves(
		Currency currencyA,
		Currency currencyB
	) internal view virtual returns (uint256 reserveA, uint256 reserveB) {
		(uint256 reserve0, uint256 reserve1, ) = pairFor(currencyA, currencyB).getReserves();
		(reserveA, reserveB) = currencyA < currencyB ? (reserve0, reserve1) : (reserve1, reserve0);
	}

	function pairFor(Currency currencyA, Currency currencyB) internal view virtual returns (IUniswapV2Pair pair) {
		assembly ("memory-safe") {
			if eq(currencyA, currencyB) {
				mstore(0x00, 0xbd969eb0) // IdenticalAddresses()
				revert(0x1c, 0x04)
			}

			if gt(currencyA, currencyB) {
				let temp := currencyA
				currencyA := currencyB
				currencyB := temp
			}

			let ptr := mload(0x40)

			mstore(ptr, shl(0x60, currencyA))
			mstore(add(ptr, 0x14), shl(0x60, currencyB))

			let salt := keccak256(ptr, 0x28)

			mstore(ptr, add(hex"ff", shl(0x58, UNISWAP_V2_FACTORY)))
			mstore(add(ptr, 0x15), salt)
			mstore(add(ptr, 0x35), UNISWAP_V2_PAIR_INIT_CODE_HASH)

			pair := and(keccak256(ptr, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)

			if iszero(extcodesize(pair)) {
				mstore(0x00, 0xcc644557) // PairNotExists(address)
				mstore(0x20, pair)
				revert(0x1c, 0x24)
			}
		}
	}

	function setPairs() internal virtual {
		IUniswapV2Pair[] memory pairs = getPairs();

		for (uint256 i; i < pairs.length; ++i) {
			vm.label(address(pairs[i]), parseTicker(pairs[i]));
		}
	}

	function getPairs() internal pure virtual returns (IUniswapV2Pair[] memory pairs) {
		pairs = new IUniswapV2Pair[](4);
		pairs[0] = IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc); // USDC-ETH
		pairs[1] = IUniswapV2Pair(0xBb2b8038a1640196FbE3e38816F3e67Cba72D940); // WBTC-ETH
		pairs[2] = IUniswapV2Pair(0x004375Dff511095CC5A197A54140a24eFEF3A416); // WBTC-USDC
		pairs[3] = IUniswapV2Pair(0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5); // DAI-USDC
	}
}
