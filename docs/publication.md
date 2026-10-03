# Publication and verification record

- Destination: [anon-coder-88/intelio](https://github.com/anon-coder-88/intelio).
- Working branch: `feat/resource-accounts-mvp`.
- Reviewable pull request: [#1 — Intelio bounded resource-account MVP](https://github.com/anon-coder-88/intelio/pull/1), open, not merged.
- Base/main remains `d7b62f0b54f3304d0b935e197b19cdb7fbcb365d`; existing history preserved. No hosted website update, branch deletion or force push.
- Published and independently tested code revision: `caed9e37a0c8780b41f1dc7b6030103728f80599`. Later documentation commits record evidence and language figures without changing protocol, SDK, reader or launcher code.
- [GitHub CI run 37083059894](https://github.com/anon-coder-88/intelio/actions/runs/37083059894): **completed, success**. All steps passed: clean npm install, native Solidity compile, Foundry tests, ABI consistency, strict TypeScript, SDK tests, actual Anvil journey, static build, formatting and language measurement. Runner used Node22; the managed local run used Node24 and official solc-js.
- Earlier CI exposed an npm optional-package bin-link collision (`forge` command absent). Fixed by resolving the pinned official platform executables directly; no tests were weakened or checks skipped in the successful run.
- Final local `npm audit`: **0 vulnerabilities** across all dependencies, after updating viem/Vite and overriding compiler dependency `tmp` to 0.2.7. This is dependency metadata evidence, not a smart-contract audit.
- Final eligible bytes: Solidity **33,170** / all languages **52,420** = **63.28%**. Includes the actual delivered SDK, frontend and tooling. The pinned upstream submodule and actual generated ABIs are excluded; tests are reported separately in language-report.md.

## Remaining acceptance and release boundaries

GitHub's default-branch language statistic is **pending reviewed merge and subsequent background processing**. Main is still empty; the feature branch's local/CI estimate does not establish default-branch acceptance. The connected GitHub fetch tool rejects the languages API endpoint, so no API byte result is claimed. After merge, verify the actual default revision's GitHub language bar or languages API and record the result.

No public-chain deployment, external security audit, service delivery integration, approved resource/token economics or production approval exists. Browser execution and original website QA remain unperformed. Those do not invalidate the recorded local account workflow; they prevent production-readiness claims.

The PR uses Conventional Commits for the actual implementation, tests, SDK, specification, CI, launcher fix and evidence. No fabricated activity, addresses, transaction receipts or backdated history was added.
