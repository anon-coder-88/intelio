# Contract reference

See `contracts/src/ResourceAccounts.sol` and generated `packages/abi/ResourceAccounts.json` for exact signatures, errors and events. The interface returns a complete `Application` struct; read stored `day` alongside `dailySpent` because the UTC-day reset occurs on the next successful charge.

| Function | Authority | Effect |
| --- | --- | --- |
| createApplication(metadata, policy) | Any wallet | Fixed creator ownership, sequential ID |
| application(id) | Public read | Full app state; rejects unknown ID |
| fund(id) payable | Any sponsor | ETH credit without authority |
| configureService(id, serviceId, operator, recipient, enabled) | Owner | Per-app service allowlist and fixed destination |
| setPolicy(id, policy) | Owner | Limits change without clearing usage |
| setMetadata(id, metadata) | Owner | Public text, 1–512 bytes |
| payUsage(id, serviceId, requestId, amount) | Enabled service's operator | Unique settlement under all limits |
| withdraw(id, recipient, amount) | Owner | Recover credited ETH, including while paused |
| setPaused(id, paused) | Owner | Stop/resume usage payments |
| closeApplication(id) | Owner | Retire permanently if balance zero |

`services` and `paidRequests` mappings have public getters; `totalLiabilities` and `nextAppId` are public. No owner rotation, protocol admin, rescue, delegatecall or unrestricted execution exists. App close leaves historical receipts and records readable. See `mvp-spec.md` for events, failure conditions and accounting semantics.
