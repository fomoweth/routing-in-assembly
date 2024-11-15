# Routing in Assembly

Implementing the Uniswap V2 & V3 SwapRouters in Yul.

## Usage

Create `.env` file with the following content:

```text
# RPC
INFURA_API_KEY="YOUR_INFURA_API_KEY"
RPC_ETHEREUM="https://mainnet.infura.io/v3/${INFURA_API_KEY}"

# BlockExplorer
ETHERSCAN_API_KEY_ETHEREUM="YOUR_ETHERSCAN_API_KEY"
ETHERSCAN_URL_ETHEREUM="https://api.etherscan.io/api"

# Test Environment (Optional)
FORK_BLOCK_ETHEREUM=21190937
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```
