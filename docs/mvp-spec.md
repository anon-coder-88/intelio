# MVP specification: bounded application resource accounts

## Candidate selection

| Candidate | Product relevance | Coherent local completion | Dependencies / implementation risk | Decision |
| --- | --- | --- | --- | --- |
| Application resource account | Central to whitepaper 05–06, 14, 22–23 | Register, fund, authorize, charge, recover, retire | Native ETH/EVM; manageable permission and accounting risks | Selected |
| Four-way fee routing | Whitepaper 12, 21 | Arithmetic alone insufficient to prove market fees | Unapproved splits, collection source, liquidity/conversion venues | Defer |
| Token launch + resource conversion | Whitepaper 11, 13, 16 | Requires launch and funding policy | Missing token details, market mechanics and pricing sources | Defer |

## Problem, users and complete workflow

Developers and application operators need a funded operating account that grants a service limited payment authority without granting ownership over treasury assets. Owners register public metadata and positive limits; sponsors fund ETH; owners configure a service ID with one operator and one fixed recipient; that operator submits a positive usage payment with an app-unique request ID. The contract checks authority, pause status, funding and all limits, transfers ETH, and emits settlement evidence. Owners can revoke a service, pause payments, withdraw unused funds while paused, and permanently close an empty account.

PRD basis is J2/J3 and REQ 009, 013, 017–019, 024, 030, 033; these remain **DEMO P0 proposed website requirements** where originally specified. This extension adds independently tested onchain enforcement; it does not silently upgrade website fidelity or claim that a simulated usage row was a transaction. Whitepaper sections 05–06, 09, 14, 16–18, 22–23 and 27–29 justify utility and boundaries.

Deferred: gateway and providers; AI inference; external tool execution; token launch; protocol token/ticker; fee collection and splits; conversion; liquidity; arbitrary calls; signatures/meta-transactions; cross-device accounts; indexing; ownership transfer; unattended scheduling; browser draft migration and website integration. No backend service is needed for this accounting MVP.

## Responsibilities and units

One non-upgradeable `ResourceAccounts` contract manages isolated application records, policy, service permissions, receipt uniqueness and aggregate liabilities. SDK supplies typed reads/writes from generated build ABIs. A static local reader supplies read/error states; an executable SDK journey covers all writes. Owners/operators use EVM transactions; inference, identity validation, prices, provider credentials and result verification remain offchain.

Every amount is integer **wei** (10^18 wei = 1 ETH), independently of gas expenditure. There are no resource-credit conversion, exchange-rate, fee, share, accrual or rounding calculations. Decimal parsing rejects more than 18 decimal places rather than rounding. Zero funding/payment/withdrawal is rejected. All credited deposits are fully accounted to one app. `sum(app.balance) = totalLiabilities <= contract ETH balance`. Successful charge or withdrawal decreases the credited balance and liabilities by the exact outgoing amount. Direct transfers are rejected; forced ETH is uncredited surplus and has no recovery function.

Valid policy: `0 < requestLimit <= dailyLimit <= lifetimeLimit`. Policy may be configured before funding and may exceed current balance; available balance separately bounds every payment. UTC calendar day = floor(block.timestamp / 86400); this is not a rolling 24-hour limit. Charges across midnight may consume two days' allowance in a short interval. Daily counter resets lazily on successful next-day payment; the reader must interpret its recorded `day` before displaying a current allowance. Lifetime spend never resets. Policy edits retain counters and cannot reduce lifetime cap below already-paid usage. Lowering daily cap below already-used capacity blocks charges until a later day or a sufficient cap increase. Zero permission/zero policy is replaced by service disable/pause.

## Authority, trust and local parameters

Fixed creator wallet owns the app. Anyone may sponsor without acquiring withdrawal rights. Only owner edits metadata, policy, service operator/recipient/enabled flag, pause, withdraw destination and closure. Operator may pay only its enabled service and fixed recipient; no arbitrary transaction calls. There is no global administrator, upgrade key or recovery authority. Owners may increase caps or replace recipients immediately; operators and users must monitor these transactions. Withdrawal leaves service authority active for future funding unless disabled or closed.

Operators are trusted to submit accurate charges and use stable request identifiers. Uniqueness prevents a reference from being charged twice within one app, including across services and days; inventing fresh IDs is not prevented. An event is not proof of AI work, price fairness, accuracy or delivery. Results and prompts should not be published as onchain metadata. Owners bear key-loss risk; no ownership transfer/recovery exists. Standard-library reentrancy protection and checks-effects-interactions cover external ETH calls; a rejected recipient reverts the whole payment and keeps its request ID retryable.

Local journey proposals: chain 31337, request limit 0.01 ETH, daily 0.02 ETH, lifetime 0.05 ETH, funding 0.1 ETH, charge 0.01 ETH. All are test parameters, not approved economics. Unit tests vary these values, including one wei and large integer boundaries. Intended future network: Robinhood Chain testnet 46630, then only an independently authorized release decision. No public address configured.

Production decisions missing: approved settlement asset and pricing policy; provider registry/delivery disputes; deployer/review owner; production caps; timestamp/chain suitability; operator custody; monitoring and incident response; wallet/account migration. D01–D08 remain open wherever relevant. They do not prevent a coherent local account implementation.

## Transitions, events and rejection conditions

| Transition | Allowed caller / condition | Event and result | Rejected cases |
| --- | --- | --- | --- |
| Create → open | Any sender; 1–512 metadata bytes; valid policy | ApplicationCreated, PolicyUpdated; sequential ID and immutable owner | Empty/oversized metadata, invalid limit ordering |
| Open/paused → funded | Any sponsor; positive ETH | Funded; exact liability credit | Unknown/closed app, zero value |
| Configure service/policy/metadata | Owner of open or paused app | ServiceConfigured / PolicyUpdated / MetadataUpdated | Wrong owner; invalid service/operator/recipient; lifetime below usage |
| Open → charged | Enabled service's operator, unique nonzero request, all limits and balance sufficient | UsagePaid; exact debit and transfer | Pause/closed; missing service; wrong caller; zero/replay; limit/balance excess; recipient failure |
| Open ↔ paused | Owner | PauseChanged | Wrong owner or closed app |
| Open/paused → withdrawn | Owner; positive amount <= credited balance; valid destination | Withdrawn; exact debit, counters retained | Wrong owner; zero/excess; zero/self recipient; external-call failure |
| Empty open/paused → closed | Owner; zero credited balance | ApplicationClosed; permanent retirement | Wrong owner; nonempty; repeated close |

## Acceptance criteria

1. Full local SDK workflow results in correct owner, service, transferred recipient ETH, daily/lifetime usage, unique request record, recoverable remaining funds and terminal closure.
2. Unauthorized, unapproved, paused, replayed, invalid and exceeded-limit charges revert without changing balances/counters/request state.
3. Policy updates and withdrawals cannot reset consumption; application funds and receipt namespaces remain isolated.
4. Failed/reentrant external calls cannot debit twice or lock a retryable charge; owner withdrawal works during pause.
5. Fuzz and stateful sequence tests enforce liability sums, asset conservation and positive-policy spending ceilings. Frontend build and SDK checks pass; ABI matches build.
6. Language measurement includes all delivered first-party source; genuine generated ABIs and upstream submodule are excluded. Default-branch verification is a separate post-merge check.
