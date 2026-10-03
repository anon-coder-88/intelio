# Dependency provenance

First-party code is MIT licensed. No contracts, business mechanics, frontend code, fonts, or imagery were copied from the organizational references or the deleted Intelio implementation.

| Dependency | Pin | Use and attribution |
| --- | --- | --- |
| OpenZeppelin Contracts | 5.4.0; npm integrity in package-lock.json | MIT; production ReentrancyGuard, no rewritten security primitive |
| forge-std | v1.11.0, 8e40513d678f392f398620b3ef2b418648b33e89 | Official maintained Foundry Test, Script, cheatcodes and invariant library; MIT/Apache-2.0; Git submodule |
| Foundry Forge/Anvil | 1.5.0 | Official executables; contract testing/local chain |
| Solidity | 0.8.30 | Official compiler; optimizer 200; Paris EVM baseline for portability |
| viem | 2.57.2 | Typed EVM interaction; no service-provider credentials |
| TypeScript / Node | 5.9.2 / 22.18.0 target | Strict SDK and example checks |
| Vite | 7.3.6 | Static local reader build, no backend |
| LinguistJS | 2.9.2 | Published Linguist implementation for local language measurement; GitHub remains authoritative |

Install source dependencies with `git submodule update --init --recursive` and `npm ci`. The submodule pins the full real test library; it is never included in first-party Solidity volume. The managed validation environment materialized its official source through the GitHub connector because direct GitHub network access was restricted. Native Forge/Anvil came from their official npm platform packages. Compiler fallback used the pinned official solc-js build through a temporary standard-JSON adapter; the EVM execution and test harness were real Foundry.
