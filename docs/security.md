# Security and trust boundaries

Non-upgradeable, no global admin. Owners control their own account policies, destinations, operators, pause and recovery. Operators can consume the entire permitted balance over allowed requests/days using fresh IDs; they are trusted billers. Metadata is public and does not authenticate application software. Use no secrets or private prompts in metadata/service IDs/request IDs.

OpenZeppelin ReentrancyGuard protects writes; usage and withdrawal update accounting before external ETH calls. Any rejected outgoing call reverts the transaction and preserves retryability. Tests exercise malicious payment callbacks and failed outgoing transfers. Owners may redirect a failed withdrawal to another recipient. A lost or compromised owner key has no recovery mechanism; a lost operator key can be replaced by owner.

Replay protection is scoped to the app and permanent. It prevents repeated settlement of one supplied reference, not offchain service fraud or content duplication under different references. No oracle, verifier or signature attests delivery. Fixed UTC days allow midnight bursts and rely on chain timestamps. Services share app-level limits; no per-operator allocation, rolling-window or price-cap verification exists beyond the owner-defined amount cap.

Unknown apps, zero amounts, invalid policies, insufficient balances and unauthorized writes revert. Recipient zero/self is rejected. Sponsors cannot reclaim funding from the contract; only the recorded owner may withdraw. Direct transfers revert; forced ETH remains uncredited and unrecoverable. Recipient contracts must accept ETH; gas exhaustion/reverts fail atomically.

No external security audit or production review has occurred. Local checks do not validate public chain behavior, external service delivery, key custody, wallet UI, browser/device accessibility or hosted website correctness. CI is provided separately; its actual status is recorded only after a workflow run.
