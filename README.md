# Intelio — application resource accounts

An extracted MVP of Intelio's programmable operating resources: register a public application identity, deposit native ETH, authorize an operator with a remaining budget, approve service recipients, and pay for usage with a reference hash. Owners can recover unspent funds. Each application has isolated accounting.

The PRD originally describes simulated drafts and budgets. This repository adds a real contract implementation of that narrow utility. It does not implement AI inference, token launches, daily limits, fee routing, or proof that a service executed. Receipt references are not unique or replay protected; every payment still consumes its own allowance and balance.

## Contents

- `contracts/contracts/IntelioResources.sol`: production utility, Solidity ^0.8.20, OpenZeppelin ReentrancyGuard.
- `contracts/contracts/test/`: executable Solidity behavioral tests and adversarial callers, not production deployments.
- `contracts/scripts/`: Hardhat TypeScript deploy and interaction scripts; browser integration smoke test.
- `web/`: existing Intelio HTML/CSS/JavaScript resource interface with EIP-6963 wallet discovery and supplied wallet icons.
- `backend/resources.py`: read-only web3.py account helper.
- `archive/website-source.zip`: complete existing website source snapshot, preserved without rewriting the marketing website.
- `docs/`: utility acceptance criteria, validation, and measured language composition.

## Run locally

Requires Node.js 20+ and Python 3.10+.

1. Copy `.env.example` to `.env`. Leave the private-key field empty for local work.
2. `cd contracts && npm ci && npm run compile && npm test`
3. In terminal A, inside `contracts`, run `npm run node` and leave it running.
4. In terminal B, inside `contracts`, run `npm run deploy:local`. This writes the deployed address and ABI into `web/config.js`.
5. From the repository root run `python -m http.server 8080 --directory web` and open http://localhost:8080.
6. Add a local wallet network: RPC http://127.0.0.1:8545, chain ID 31337. Hardhat's printed development accounts are public and must only be used locally.
7. Connect a wallet, register an application, deposit ETH, authorize an operator and recipient, then submit a usage payment. Each write needs wallet approval.
8. For automated browser-control integration, run `node scripts/ui-smoke.cjs` from `contracts` after a local deployment. It uses a disposable local RPC wallet adapter, not a real browser extension.

## Robinhood Chain testnet

The default network is Robinhood Chain testnet, chain ID 46630 and RPC https://rpc.testnet.chain.robinhood.com. See the [official deployment documentation](https://docs.robinhood.com/chain/deploy-smart-contracts/).

Put a dedicated testnet deployer's key in your ignored `.env`, obtain testnet ETH, then run `npm run deploy:testnet` from `contracts`. Serve `web` again. The frontend refuses transactions if the wallet network differs from configuration or the configured address has no code. Contracts have been locally verified; no testnet deployment is included.

For CLI actions, set `CONTRACT_ADDRESS`, `ACTION`, and the corresponding values in `.env`, then run `npm run interact`. Supported actions: read, create, deposit, operator, recipient, pay, withdraw. Read actions require no private key.

For Python: `python -m venv .venv`, activate it, then `pip install -r backend/requirements.txt`. Set `RH_RPC_URL`, `CHAIN_ID`, `CONTRACT_ADDRESS` and `APP_ID`, then run `python backend/resources.py`. Compile first to export `web/abi.json`.

## Accounting and permissions

An allowance replaces the remaining operator budget; zero revokes it. It is not a reserved balance and may exceed the funded account. Payments need both sufficient allowance and funded balance. Withdrawals do not revoke outstanding operator authority. Owners should revoke operators before refilling accounts when appropriate. Metadata is public, immutable, and limited to 512 bytes. Failed recipient transfers revert all payment accounting; external calls are guarded against reentrancy.

The repository includes Solidity regression tests in its code-language calculation. Third-party browser ethers and generated ABI files are identified accurately in `.gitattributes`; no first-party language is relabeled. The preserved website ZIP is binary and naturally outside language statistics. Run `python scripts/language_share.py` to reproduce the first-party code byte calculation. This reports the extracted runnable MVP; unzipping the full website into the repository would change its language composition.

