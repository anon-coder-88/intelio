# Contributing

Initialize submodules and run `npm ci`. Read `docs/mvp-spec.md` before changing accounting or permissions. Use a working branch and Conventional Commits, e.g. `feat(protocol): add bounded service payments` or `test(accounting): preserve liabilities during failed withdrawals`.

Run compile, contract tests, ABI consistency, SDK typecheck/unit tests, local integration, static reader build and formatting. Regenerate ABI from actual build when interfaces change. Add behavioral regressions for changed financial or permission rules; keep mocks in tests. Never weaken invariant assertions or substitute an assertion shim.

Update specification, security and validation evidence as applicable. Measure all tracked first-party source with `npm run language`; dependencies and generated ABI may be excluded accurately, never first-party UI or SDK. Keep secrets, addresses without provenance and build output out of commits. Review and merge through a PR; no force pushes or automatic mainnet release.
