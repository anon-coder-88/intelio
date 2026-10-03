# Architecture

`ResourceAccounts` is canonical for ownership, balances, policy, service authorization and paid request IDs. One contract provides isolated application ledgers over a pooled native ETH balance; liabilities track the sum. No proxy, token, gateway, oracle, database or indexer is involved.

The owner configures scope; a designated offchain service operator submits a charge transaction; the contract checks scope and transfers ETH to the service's configured destination. Inference and service credentials remain offchain. Operator billing correctness and delivery are trust assumptions, not facts established by events. Contracts never wake themselves or schedule work.

`packages/abi` is generated from `forge build`. `packages/sdk` wraps that ABI with typed viem methods. `scripts/local-journey.ts` submits and verifies actual Anvil transactions. `apps/web` is a separate static local reader with clear chain/error state. No hosted website source was imported. Read `source-analysis.md` for deleted historical sources inspected.

Future website integration would supply a reviewed address/chain registry, use the SDK with an explicit wallet account, display pending/success/reverted receipts separately, invalidate cached state on account/chain changes, and keep browser demo balances separate from onchain wei. It requires a separate user request and website source review. Offchain services need authenticated request IDs, prices, monitoring, and dispute policy before deployment; no adapter silently replaces them.
