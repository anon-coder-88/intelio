# Language report

## Local measured estimate

Method: published **LinguistJS 2.9.2**, offline bundled GitHub Linguist language/generated/vendor/documentation definitions, normal attribute and heuristic checks, only `programming` and `markup` categories. Every classified tracked file is measured by raw UTF-8 byte length. All delivered frontend, SDK, deployment, contract tests and measurement/journey scripts are included. `npm run language` reproduces the estimate and fails below 50%.

Measured local code revision: `13e2d5fc2b72c2e418a05e9a510ecab560ea7ed4`. Later lockfile/documentation-only commits do not change eligible language bytes. This revision belongs to local preparation; the GitHub PR commit is recorded in publication.md after push. Published code revision: `caed9e37a0c8780b41f1dc7b6030103728f80599`. The source tree is verified against the published files. LinguistJS is a published implementation, not the official Ruby engine; the local result is explicitly an estimate until GitHub processes the default branch.

| Eligible language | Bytes |
| --- | ---: |
| Solidity | 33,170 |
| TypeScript | 10,844 |
| JavaScript | 5,588 |
| HTML | 1,732 |
| CSS | 1,086 |
| **All eligible languages** | **52,420** |

**Solidity = 33,170 / 52,420 × 100 = 63.28%.** The percentage exceeds the requested 50% with margin. No code was added merely to tune the ratio to 55–60%; the tests exercise the selected permission/accounting workflow.

| First-party Solidity category | Bytes | Purpose |
| --- | ---: | --- |
| Protocol implementation | 9,116 | ResourceAccounts |
| Tests and isolated fixtures | 23,524 | 45 unit/fuzz tests, three stateful invariants, adversarial recipients and multi-app handler |
| Deployment script | 530 | Local chain guard and deployment |
| **Total** | **33,170** | No dependency source counted |

## Exclusions

- Official forge-std submodule at `8e40513d678f392f398620b3ef2b418648b33e89`: upstream dependency, not first-party code. `.gitattributes` marks only this dependency vendored. The materialized local dependency files are not shipped as inflated Solidity source.
- `packages/abi/ResourceAccounts.json` and `packages/abi/index.ts`: actual build-generated ABI, marked generated. Exporter remains included; `abi:check` detects drift.
- Installed `node_modules`, build output, compiler cache and broadcast files: untracked/ignored, not part of the delivered tree.
- Markdown is prose; JSON/TOML/YAML are data under Linguist's default categories. The lockfile, docs, CI and config remain delivered; no first-party source is relabelled or forced nondetectable.
- No zipped first-party frontend, removed SDK, vendored contracts copied into the numerator, duplicated contracts, unrelated ecosystem modules or language overrides. Historical deleted website archive was inspected only as a history entry and was not reintroduced.

## GitHub default-branch status

Current `main` at `d7b62f0b54f3304d0b935e197b19cdb7fbcb365d` is empty. Work is published for review on `feat/resource-accounts-mvp`; no main update or merge is performed. **Default-branch >=50% acceptance remains pending**, regardless of the feature branch's estimate. After reviewed merge, inspect `https://api.github.com/repos/anon-coder-88/intelio/languages` and the GitHub language bar once its background processing finishes; divide returned Solidity bytes by the sum. Record the merged SHA, API bytes and processing time. An empty/stale result is not a pass.

Primary methodology: [How Linguist works](https://github.com/github-linguist/linguist/blob/main/docs/how-linguist-works.md), [overrides](https://github.com/github-linguist/linguist/blob/main/docs/overrides.md), and [LinguistJS](https://github.com/Nixinova/Linguist).
