# Executed validation

Validation date: 3 October 2026 UTC / Asia-Jakarta. Linux x86_64 managed container; Node **24.19.0**, npm **11.9.0**, Forge and Anvil **1.5.0**, Solidity **0.8.30+commit.73712a01** (official solc-js), viem **2.57.2**, TypeScript **5.9.2**, Vite **7.3.6**, full official forge-std **v1.11.0**. CI targets Node 22.18.0; that exact release and the native compiler were independently executed successfully by GitHub Actions (linked below).

## Results

| Command / check | Actual result | Evidence boundary |
| --- | --- | --- |
| `FOUNDRY_SOLC=/tmp/intelio-solc.cjs npm run compile` | PASS; real Solidity compilation | Temporary standard-JSON solc-js adapter used because native compiler retrieval was restricted |
| `FOUNDRY_SOLC=/tmp/intelio-solc.cjs npm run test:contracts` | PASS, 48 tests, 0 failed/skipped | 41 unit tests + four fuzz tests ×256 inputs; three invariants ×128 runs ×64 calls, zero handler reverts |
| `npm run abi:check` | PASS | ABI equals compiled artifact |
| `npm run format:check` | PASS | Forge fmt + Prettier for all maintained TS/JS/HTML/CSS |
| `npm run typecheck` | PASS | Strict SDK, reader and integration TypeScript |
| `npm run test:sdk` | PASS, two tests | Exact wei conversion and invalid/precision input rejection |
| `npm run test:integration` | PASS | Actual Anvil EVM transactions through SDK; local chain only |
| `npm run build:web` | PASS | Static local reader production bundle; Vite 7.3.6 |
| `npm run language` | PASS local estimate: 63.28% Solidity | LinguistJS 2.9.2; default branch pending reviewed merge |

Local journey deployed a fresh contract, registered an application, configured service/operator/recipient, funded 0.1 ETH, paid 0.01 ETH, checked recipient balance and paid-request flag, rejected unauthorized/excess/replayed charges, paused and rejected a further charge, withdrew remaining 0.09 ETH, then closed. Final app balance, total liabilities and contract balance are zero; lifetime usage remains 0.01 ETH. Its address is ephemeral Anvil state and is not a public deployment.

Solidity tests cover identity, sponsorship isolation, owner-only controls, unknown/disabled services, operator rotation, zero amounts/request IDs, inclusive/one-wei-excess request/daily/lifetime boundaries, UTC rollover, policy changes without resets, replay across services/days and separate apps, insufficient balances and retry, failed payment/withdrawal recovery, reentrancy during payment, pause/withdrawal recovery, terminal closure, metadata bounds, direct-transfer rejection and forced surplus. Stateful invariants verify liabilities equal summed balances, deposits equal remaining resources plus withdrawals plus payments, provider receipt equals total charges and spending ceilings hold. Mocks are confined to adversarial fixtures; they do not impersonate AI providers.

Initial failures were corrected: Foundry's reserved `testFail*` prefix required renaming two explicitly asserted failure tests; tsx CLI needed Unix IPC unavailable in this container, so scripts use its supported Node import hook; LinguistJS version/API was aligned with the supported Node target. A clean GitHub install then exposed an npm Foundry optional-package command-link collision; the launcher now resolves the official pinned executables directly. Local npm ci, tests and the journey were rerun after that change. Assertions were not removed, counts were not suppressed, and errors were not relabelled successful.

Dependency audit triggered viem/Vite updates and a pinned `tmp` override for the compiler package; final audit result is recorded in publication.md. Audit output is a dependency check, not a protocol audit.

## Unperformed / pending

- **No public testnet or mainnet transaction**, contract verification, real provider billing, gateway request, inference or delivery attestation.
- **No hosted website modification or website QA**. Existing PRD FULL/DEMO/PLACEHOLDER and NFR criteria remain independent of this protocol result.
- Browser execution was attempted, but the installed Playwright runtime had no Chromium executable. Reader browser/device, keyboard, responsive and accessibility checks are **unperformed**; only typecheck and production build passed.
- GitHub Actions independently passed every configured check on native solc 0.8.30 and Node22 at code revision `caed9e37a0c8780b41f1dc7b6030103728f80599`; see [successful run](https://github.com/anon-coder-88/intelio/actions/runs/37083059894). Later evidence-only commits preserve the tested code.
- No external security audit, production readiness, approval of economics, operating-service integrations, or owner-key recovery.
- GitHub language bar/API verification on the default branch is pending merge/background processing; local measurement does not establish that acceptance.

Reproduce the normal native-toolchain commands in README and deployment.md. All test fixtures and assertions are tracked; the full forge-std dependency is pinned as an upstream Git submodule, not an assertion shim.
