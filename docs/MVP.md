# Derived MVP: application resource accounts

The PRD connects application identities, models/tools, and controlled operating resources. Its first website release uses simulated drafts and budgets. This extracted utility adds real smart-contract enforcement for identity and native ETH resource accounting.

1. Register an immutable public metadata URI and obtain an application ID.
2. Sponsor an application; each application balance stays separate.
3. Only the owner configures operator budgets and approved service recipients.
4. Authorized payments atomically debit the operator allowance and application balance.
5. UsagePaid events record reference hashes, not proof of service execution. Repeated hashes are allowed.
6. Only the owner withdraws unspent funds; failed transfers roll back accounting, and reentrancy is blocked.
7. Browser writes require explicit wallet approval; no private keys are tracked.

Out of scope: AI inference, external tool execution, daily/request limits, automatic runs, tokens, fee routing and service attestation.

Delivery stages: review and preserve existing source; extract the utility; compile and test; measure Solidity share; push verified source to intelio. Production deployments exclude all contracts under contracts/contracts/test.
