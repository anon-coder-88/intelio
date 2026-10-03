# Intelio — programmable resource accounts

Intelio connects intelligent applications with bounded operating resources. This repository implements a focused local protocol MVP: **register an application, fund an ETH account, authorize a service operator, settle unique usage charges within request/daily/lifetime limits, and recover unused funds**.

The MVP derives from the Intelio whitepaper's resource accounts and programmable spending (sections 05–06, 14, 22–23), and PRD journeys J2/J3. It is a separately authorized extension of the PRD's frontend-only website scope. The hosted Intelio website is unchanged.

## Implemented utility

- Fixed owner and public application metadata; isolated balances.
- Native ETH funding by any sponsor; all accounting in integer wei.
- Owner-defined request, UTC daily and cumulative lifetime ceilings.
- Service-specific operator and fixed payment recipient; immediate revoke/pause controls.
- Unique app-scoped request IDs; atomic payment and settlement events.
- Owner withdrawals during pause and permanent retirement of empty accounts.
- Generated ABI, typed viem SDK, full local transaction journey and a separate static local reader.
- Real Foundry unit, fuzz and stateful invariant tests; CI configuration and reproducible measurement.

**Current status:** local implementation and validation; no public deployment, external security audit, production approval, gateway, inference integration, protocol token or approved conversion policy. Onchain payment records prove settlement under contract rules; they do not prove offchain work occurred. An authorized operator is a trusted biller.

## Repository layout

| Path | Purpose |
| --- | --- |
| contracts/src | ResourceAccounts protocol |
| contracts/test | Foundry tests and isolated adversarial fixtures |
| contracts/script | Local-only deployment script |
| apps/web | Separate static localhost reader; original hosted source not imported |
| packages/sdk | Typed contract helpers and wei parsing tests |
| packages/abi | ABI generated from actual compilation |
| scripts | ABI export, local-chain journey and language measurement |
| docs | Source analysis, MVP, architecture, rules, deployment, security and validation |
| vendor/forge-std | Official pinned test library submodule, excluded from first-party statistics |

## Quick start

Node 22.18+ and supported Foundry platform required. Dependencies and compatible compiler versions are pinned; the lockfile records npm integrity.

```sh
git clone --recurse-submodules https://github.com/anon-coder-88/intelio.git
cd intelio
# Until merged, check out the pull request's working branch.
git checkout feat/resource-accounts-mvp
git submodule update --init --recursive
npm ci
npm run compile
npm run abi:check
npm run test:contracts
npm run typecheck
npm run test:sdk
npm run test:integration
npm run build:web
npm run format:check
npm run language
```

The integration command starts a disposable Anvil chain, submits real deployment/registration/funding/charge/pause/withdrawal/closure transactions through the SDK, checks balances and rejected actions, and shuts the chain down. It requires no private-key input. All local accounts are development-only. For a persistent local deployment and the reader, see [deployment](docs/deployment.md).

## Boundaries and trust

Owners may change caps and service recipients immediately. Sponsors transfer control of funding to the recorded owner. Operators may submit fresh request IDs and consume the available policy allowance; no price or delivery verifier is implemented. Native ETH is a development accounting choice, not an approved Intelio resource conversion or token economic policy. Ticker remains unspecified.

No global administrator, proxy or ownership-recovery mechanism exists. Owner withdrawals do not revoke operator access to later deposits. UTC calendar days are not rolling 24-hour windows. Failed transfers revert all charge state and remain retryable. Forced ETH is uncredited and unrecoverable. Review [security boundaries](docs/security.md), [MVP specification](docs/mvp-spec.md) and [source inventory](docs/source-analysis.md).

Robinhood Chain is the intended product network; official configuration was checked, but only chain 31337 was executed. No testnet/mainnet address or transaction is claimed. Website integration and future public deployment require separate work and authorization. Intelio is independently developed and is not affiliated with or endorsed by Robinhood or Robinhood Digital Assets.

See [executed validation](docs/validation.md) and [language report](docs/language-report.md). GitHub's default-branch language acceptance remains pending until the reviewed PR is merged and GitHub processes the new default tree. License: MIT; dependency attribution in [dependencies](docs/dependencies.md).
