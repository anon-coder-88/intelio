# Local deployment and future network boundary

Install Node 22.18+, then `git submodule update --init --recursive` and `npm ci`. Official Foundry 1.5.0 npm launchers provide `forge` and `anvil` for supported platforms. A system Foundry installation may also be used. Compiler 0.8.30 is required.

```sh
npm run compile
npm run abi
npm run test:contracts
npm run test:sdk
npm run test:integration
```

The integration command starts Anvil on loopback port 18545, uses public unlocked development accounts, deploys and completes the journey, asserts final balances and closes the process. Keys are never supplied or printed. It refuses a public RPC/chain. The reported address exists only for that disposable process and is not a public deployment.

For a persistent local reader, start `npx anvil --host 127.0.0.1 --port 8545` in one terminal. In another terminal run `node --import tsx scripts/local-journey.ts`; keep the chain running. The printed local address and application ID (also written to `/tmp/intelio-local-deployment.json`) can be entered in `npm run dev:web`. The journey leaves the app closed with a zero balance. `DeployLocal.s.sol` is an additional reproducible local script guarded to chain 31337:

```sh
npx forge script contracts/script/DeployLocal.s.sol:DeployLocal --rpc-url http://127.0.0.1:8545 --unlocked --sender <ANVIL_ADDRESS> --broadcast
```

Use `cast rpc eth_accounts --rpc-url http://127.0.0.1:8545` or the Anvil startup output to select an unlocked local sender. Do not use development accounts on any public network.

In the managed validation environment, native solc download was restricted. `FOUNDRY_SOLC=/tmp/intelio-solc.cjs` pointed Forge to a temporary adapter invoking the pinned official `solc` package's standard JSON compiler; no bytecode, assertions or test runner were substituted. Reproduction outside that environment uses native solc normally.

## Intended Robinhood context; no public deployment

| Setting | Mainnet | Testnet |
| --- | --- | --- |
| Chain ID | 4663 | 46630 |
| Gas | ETH | ETH |
| Public RPC | https://rpc.mainnet.chain.robinhood.com | https://rpc.testnet.chain.robinhood.com |
| Explorer | https://robinhoodchain.blockscout.com | https://explorer.testnet.chain.robinhood.com |

Reverified against [primary documentation](https://docs.robinhood.com/chain/connecting/). Public RPC is rate-limited and not recommended for production. These are configuration references, not reachability or compatibility evidence. No testnet funds, deployment, address, contract verification, transaction hash or mainnet operation is claimed. Future deployment needs explicit authorization, asset/policy approval, independent review, network EVM compatibility checks and a suitable RPC provider.
