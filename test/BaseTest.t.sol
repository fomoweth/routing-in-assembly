// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {IUniswapV3Pool} from "src/interfaces/external/Uniswap/V3/IUniswapV3Pool.sol";
import {IUniswapV2Pair} from "src/interfaces/external/Uniswap/V2/IUniswapV2Pair.sol";
import {CurrencyNamer} from "src/libraries/CurrencyNamer.sol";
import {Currency} from "src/types/Currency.sol";
import {Routing} from "src/Routing.sol";

abstract contract BaseTest is Test {
	using CurrencyNamer for Currency;

	address immutable SENDER = makeAddr("SENDER");
	address immutable RECIPIENT = makeAddr("RECIPIENT");

	uint256 constant MAX_UINT256 = (1 << 256) - 1;
	uint256 constant DEADLINE = (1 << 48) - 1;

	Currency constant WETH = Currency.wrap(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
	Currency constant DAI = Currency.wrap(0x6B175474E89094C44Da98b954EedeAC495271d0F);
	Currency constant UNI = Currency.wrap(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
	Currency constant USDC = Currency.wrap(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
	Currency constant WBTC = Currency.wrap(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);

	Routing routing;

	function setUp() public virtual {
		fork();

		vm.label(address(routing = new Routing()), "Routing");

		deal(SENDER, 1000 ether);

		vm.startPrank(SENDER);

		Currency[] memory currencies = getCurrencies();

		for (uint256 i; i < currencies.length; ++i) {
			vm.label(Currency.unwrap(currencies[i]), currencies[i].symbol());

			currencies[i].approve(address(routing), MAX_UINT256);
		}

		vm.stopPrank();
	}

	function deal(Currency currency, address account, uint256 amount) internal {
		deal(Currency.unwrap(currency), account, amount);
	}

	function fork() internal {
		uint256 forkBlock = vm.envOr("FORK_BLOCK_ETHEREUM", uint256(0));

		if (forkBlock != 0) {
			vm.createSelectFork(vm.envString("RPC_ETHEREUM"), forkBlock);
		} else {
			vm.createSelectFork(vm.envString("RPC_ETHEREUM"));
		}
	}

	function parseTicker(IUniswapV3Pool pool) internal view virtual returns (string memory ticker) {
		ticker = string.concat(
			"UNI-V3: ",
			Currency.wrap(pool.token0()).symbol(),
			"-",
			Currency.wrap(pool.token1()).symbol(),
			"/",
			vm.toString(pool.fee())
		);
	}

	function parseTicker(IUniswapV2Pair pair) internal view virtual returns (string memory ticker) {
		ticker = string.concat(
			"UNI-V2: ",
			Currency.wrap(pair.token0()).symbol(),
			"-",
			Currency.wrap(pair.token1()).symbol()
		);
	}

	function getCurrencies() internal pure virtual returns (Currency[] memory currencies) {
		currencies = new Currency[](4);
		currencies[0] = WETH;
		currencies[1] = WBTC;
		currencies[2] = DAI;
		currencies[3] = USDC;
	}

	function getCurrencies(
		Currency currency0,
		Currency currency1
	) internal pure virtual returns (Currency[] memory currencies) {
		currencies = new Currency[](2);
		currencies[0] = currency0;
		currencies[1] = currency1;
	}

	function getCurrencies(
		Currency currency0,
		Currency currency1,
		Currency currency2
	) internal pure virtual returns (Currency[] memory currencies) {
		currencies = new Currency[](3);
		currencies[0] = currency0;
		currencies[1] = currency1;
		currencies[2] = currency2;
	}

	function getCurrencies(
		Currency currency0,
		Currency currency1,
		Currency currency2,
		Currency currency3
	) internal pure virtual returns (Currency[] memory currencies) {
		currencies = new Currency[](4);
		currencies[0] = currency0;
		currencies[1] = currency1;
		currencies[2] = currency2;
		currencies[3] = currency3;
	}

	function getPoolFees(uint24 fee0) internal pure virtual returns (uint24[] memory fees) {
		fees = new uint24[](1);
		fees[0] = fee0;
	}

	function getPoolFees(uint24 fee0, uint24 fee1) internal pure virtual returns (uint24[] memory fees) {
		fees = new uint24[](2);
		fees[0] = fee0;
		fees[1] = fee1;
	}

	function getPoolFees(uint24 fee0, uint24 fee1, uint24 fee2) internal pure virtual returns (uint24[] memory fees) {
		fees = new uint24[](3);
		fees[0] = fee0;
		fees[1] = fee1;
		fees[2] = fee2;
	}
}
