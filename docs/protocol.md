# Protocol rules

Native ETH deposited through `fund` backs operational budgets one-for-one in wei. It is not an Intelio token or a promise of AI credit redemption. Sponsors irrevocably assign deposits to the selected application's owner; verify that owner first.

Only the service's configured operator may charge; the service recipient is fixed at payment execution. All enabled services share the application's request/daily/lifetime ceilings. Policy updates are immediate and never clear usage. Requests are unique per application, regardless of service or day. An operator can intentionally choose new IDs; replay protection does not validate billing fairness.

Owner may pause usage and withdraw any remaining funds at any time, including during a pause. Funding remains possible during pause. Withdrawals do not revoke services; close or disable authorization before future sponsorship when appropriate. Empty accounts may close permanently. Closure prohibits funding, payment and configuration; historical reads remain valid.

UTC day boundaries permit spending on both sides of midnight. Lifetime cap persists until the owner raises it; withdrawals and refills cannot renew it. A failed transfer rolls back balances, counters and paid request flags. Forced ETH does not become a resource credit, and there is intentionally no surplus recovery administrator.
