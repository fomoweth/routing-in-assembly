// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IQuoter} from "src/interfaces/external/Uniswap/V3/IQuoter.sol";
import {IUniswapV3Pool} from "src/interfaces/external/Uniswap/V3/IUniswapV3Pool.sol";
import {Arrays} from "src/libraries/Arrays.sol";
import {Currency} from "src/types/Currency.sol";
import {BaseTest} from "./BaseTest.t.sol";

contract V3RoutingTest is BaseTest {
	using Arrays for Currency[];
	using Arrays for uint24[];

	address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

	bytes32 constant UNISWAP_V3_POOL_INIT_CODE_HASH =
		0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

	IQuoter constant UNISWAP_V3_QUOTER = IQuoter(0x5e55C9e631FAE526cd4B0526C4818D6e0a9eF0e3);

	function setUp() public virtual override {
		super.setUp();
		setPools();
	}

	function test_exactInputForSingleHop() public virtual {
		performTrades(getCurrencies(WETH, USDC), getPoolFees(3000), 10 ether, true);
	}

	function test_exactInputFor2Hops() public virtual {
		performTrades(getCurrencies(WETH, WBTC, USDC), getPoolFees(3000, 3000), 10 ether, true);
	}

	function test_exactInputFor3Hops() public virtual {
		performTrades(getCurrencies(WETH, WBTC, USDC, DAI), getPoolFees(3000, 3000, 100), 10 ether, true);
	}

	function test_exactOutputForSingleHop() public virtual {
		performTrades(getCurrencies(WETH, USDC), getPoolFees(3000), 10000 * (1e6), false);
	}

	function test_exactOutputFor2Hops() public virtual {
		performTrades(getCurrencies(WETH, WBTC, USDC), getPoolFees(3000, 3000), 10000 * (1e6), false);
	}

	function test_exactOutputFor3Hops() public virtual {
		performTrades(getCurrencies(WETH, WBTC, USDC, DAI), getPoolFees(3000, 3000, 100), 10000 ether, false);
	}

	function performTrades(
		Currency[] memory currencies,
		uint24[] memory fees,
		uint256 amount,
		bool isExactInput
	) internal virtual returns (uint256 amountIn, uint256 amountOut) {
		uint256 length = (currencies.length * 20) + (fees.length * 3);
		bytes memory path = encodePath(currencies, fees, isExactInput);
		assertTrue(length == path.length, "INVALID_PATH");

		Currency currencyIn = currencies[0];
		Currency currencyOut = currencies[currencies.length - 1];

		if (isExactInput) {
			(amountOut, , , ) = UNISWAP_V3_QUOTER.quoteExactInput(path, amountIn = amount);
			assertTrue(amountOut != 0, "INSUFFICIENT_OUTPUT_AMOUNT");
		} else {
			(amountIn, , , ) = UNISWAP_V3_QUOTER.quoteExactOutput(path, amountOut = amount);
			assertTrue(amountIn != 0, "INSUFFICIENT_INPUT_AMOUNT");
		}

		deal(currencyIn, SENDER, amountIn);

		uint256 balanceIn = currencyIn.balanceOf(SENDER);
		uint256 balanceOut = currencyOut.balanceOf(RECIPIENT);

		vm.prank(SENDER);

		if (isExactInput) {
			amountOut = routing.exactInput(path, RECIPIENT, amountIn, amountOut, DEADLINE);
		} else {
			amountIn = routing.exactOutput(path, RECIPIENT, amountOut, amountIn, DEADLINE);
		}

		assertEq(currencyIn.balanceOf(SENDER), balanceIn - amountIn, "balanceIn");
		assertEq(currencyOut.balanceOf(RECIPIENT), balanceOut + amountOut, "balanceOut");
	}

	function quoteExactInput(
		Currency[] memory currencies,
		uint24[] memory fees,
		uint256 amountIn
	) internal view virtual returns (uint256 amountOut) {
		bytes memory path = encodePath(currencies, fees, true);

		(amountOut, , , ) = UNISWAP_V3_QUOTER.quoteExactInput(path, amountIn);
	}

	function quoteExactOutput(
		Currency[] memory currencies,
		uint24[] memory fees,
		uint256 amountOut
	) internal view virtual returns (uint256 amountIn) {
		bytes memory path = encodePath(currencies, fees, false);

		(amountIn, , , ) = UNISWAP_V3_QUOTER.quoteExactOutput(path, amountOut);
	}

	function encodePath(
		Currency[] memory currencies,
		uint24[] memory fees,
		bool isExactInput
	) internal pure virtual returns (bytes memory path) {
		if (!isExactInput) {
			currencies = currencies.reverse();
			fees = fees.reverse();
		}

		path = abi.encodePacked(currencies[0]);

		for (uint256 i; i < fees.length; ++i) {
			path = abi.encodePacked(path, fees[i], currencies[i + 1]);
		}
	}

	function setPools() internal virtual {
		IUniswapV3Pool[] memory pools = getPools();

		for (uint256 i; i < pools.length; ++i) {
			vm.label(address(pools[i]), parseTicker(pools[i]));
		}
	}

	function getPools() internal pure virtual returns (IUniswapV3Pool[] memory pools) {
		pools = new IUniswapV3Pool[](4);
		pools[0] = IUniswapV3Pool(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8); // USDC-ETH 3000
		pools[1] = IUniswapV3Pool(0xCBCdF9626bC03E24f779434178A73a0B4bad62eD); // WBTC-ETH 3000
		pools[2] = IUniswapV3Pool(0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35); // WBTC-USDC 3000
		pools[3] = IUniswapV3Pool(0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168); // DAI-USDC 100
	}
}
