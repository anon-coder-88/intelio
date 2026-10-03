import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import linguist from "linguist-js";

// Published Linguist implementation: pinned bundled rules, standard detectable categories,
// repository attributes, generated/vendored filters; no frontend or SDK exclusion.
const result = await linguist(["."], {
  offline: true,
  categories: ["programming", "markup"],
  keepVendored: false,
  quick: false,
  relativePaths: true,
});
const tracked = new Set(
  execFileSync("git", ["ls-files", "-z"], { encoding: "utf8" })
    .split("\0")
    .filter(Boolean),
);
const bytes = {};
const included = [];
for (const [path, language] of Object.entries(result.files.results)) {
  const relative = path.replace(/^\.\//, "");
  if (!language || !tracked.has(relative)) continue;
  // Buffer lengths are the acceptance metric, never file/line counts or JS code units.
  const size = readFileSync(relative).length;
  bytes[language] = (bytes[language] ?? 0) + size;
  included.push({ path: relative, language, bytes: size });
}
const total = Object.values(bytes).reduce((sum, value) => sum + value, 0);
const solidity = bytes.Solidity ?? 0;
const groups = { protocol: 0, tests: 0, deployment: 0 };
for (const file of included.filter((file) => file.language === "Solidity")) {
  if (file.path.startsWith("contracts/src/")) groups.protocol += file.bytes;
  if (file.path.startsWith("contracts/test/")) groups.tests += file.bytes;
  if (file.path.startsWith("contracts/script/"))
    groups.deployment += file.bytes;
}
console.log(
  JSON.stringify(
    {
      tool: "linguist-js",
      version: JSON.parse(readFileSync("node_modules/linguist-js/package.json"))
        .version,
      rules: "offline bundled Linguist definitions",
      revision: execFileSync("git", ["rev-parse", "HEAD"], {
        encoding: "utf8",
      }).trim(),
      languageBytes: bytes,
      eligibleBytes: total,
      solidityPercent: total ? (100 * solidity) / total : 0,
      firstPartySolidityBytes: groups,
      files: included,
    },
    null,
    2,
  ),
);
if (!total || solidity / total < 0.5) process.exitCode = 1;
