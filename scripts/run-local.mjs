import { foundryBinary } from "./foundry.mjs";
import { spawn } from "node:child_process";
import { setTimeout } from "node:timers/promises";
const port = 18545;
const rpc = `http://127.0.0.1:${port}`;
const anvil = spawn(
  foundryBinary("anvil"),
  ["--host", "127.0.0.1", "--port", String(port), "--silent"],
  { stdio: ["ignore", "ignore", "pipe"] },
);
let failure;
anvil.on("error", (error) => {
  failure = error;
});
anvil.stderr.on("data", (data) => process.stderr.write(data));
try {
  let ready = false;
  for (let attempt = 0; attempt < 50; attempt++) {
    if (failure) throw failure;
    if (anvil.exitCode !== null)
      throw new Error("Anvil exited before readiness");
    try {
      const response = await fetch(rpc, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          jsonrpc: "2.0",
          id: 1,
          method: "eth_chainId",
          params: [],
        }),
      });
      if ((await response.json()).result === "0x7a69") {
        ready = true;
        break;
      }
    } catch {}
    await setTimeout(100);
  }
  if (!ready) throw new Error("Local chain did not become ready");
  const journey = spawn(
    process.execPath,
    ["--import", "tsx", "scripts/local-journey.ts"],
    {
      stdio: "inherit",
      env: { ...process.env, LOCAL_RPC_URL: rpc },
    },
  );
  const code = await new Promise((resolve, reject) => {
    journey.on("error", reject);
    journey.on("exit", resolve);
  });
  if (code !== 0) throw new Error("Local SDK journey failed");
} finally {
  anvil.kill("SIGTERM");
}
