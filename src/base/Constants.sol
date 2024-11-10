// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title Constants

abstract contract Constants {
	address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

	address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

	address internal constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

	bytes32 internal constant UNISWAP_V2_PAIR_INIT_CODE_HASH =
		0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

	address internal constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

	bytes32 internal constant UNISWAP_V3_POOL_INIT_CODE_HASH =
		0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

	// bytes32(uint256(keccak256("V3Routing.amountInCached.slot")) - 1) & ~bytes32(uint256(0xff))
	bytes32 internal constant AMOUNT_IN_CACHED_SLOT =
		0xc1581fd12e13df4ec0aff0e7b8bcfad3147501d56d112bbfd14b1a6d721bd000;

	uint8 internal constant ADDR_SIZE = 20;
	uint8 internal constant FEE_SIZE = 3;
	uint8 internal constant NEXT_OFFSET = 23; // ADDR_SIZE + FEE_SIZE
	uint8 internal constant POP_OFFSET = 43; // NEXT_OFFSET + ADDR_SIZE
	uint8 internal constant MULTIPLE_POOLS_MIN_LENGTH = 66; // POP_OFFSET + NEXT_OFFSET

	uint160 internal constant MIN_SQRT_PRICE_LIMIT = 4295128740;
	uint160 internal constant MAX_SQRT_PRICE_LIMIT = 1461446703485210103287273052203988822378723970341;
}
