import { createRequire } from "node:module";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

/** Resolve the official pinned executable directly, avoiding npm optional-package bin collisions. */
export function foundryBinary(tool) {
  if (!["forge", "anvil"].includes(tool))
    throw new Error("Unsupported Foundry tool");
  const os = { linux: "linux", darwin: "darwin", win32: "win32" }[
    process.platform
  ];
  const arch = { x64: "amd64", arm64: "arm64" }[process.arch];
  if (!os || !arch)
    throw new Error("Unsupported Foundry platform; use a supported platform");
  const filename = process.platform === "win32" ? `${tool}.exe` : tool;
  return createRequire(import.meta.url).resolve(
    `@foundry-rs/${tool}-${os}-${arch}/bin/${filename}`,
  );
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const result = spawnSync(
    foundryBinary(process.argv[2]),
    process.argv.slice(3),
    { stdio: "inherit" },
  );
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
}
