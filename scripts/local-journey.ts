import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import {
  createPublicClient,
  createWalletClient,
  http,
  keccak256,
  toHex,
  parseEventLogs,
  type Address,
  type Hex,
} from "viem";
import { foundry } from "viem/chains";
import { resourceAccounts, toWei } from "../packages/sdk/src/index.js";
import { resourceAccountsAbi } from "../packages/abi/index.js";

const rpc = process.env.LOCAL_RPC_URL ?? "http://127.0.0.1:8545";
if (!["127.0.0.1", "localhost", "[::1]"].includes(new URL(rpc).hostname))
  throw new Error("Local RPC only");
const publicClient = createPublicClient({
  chain: foundry,
  transport: http(rpc),
});
assert.equal(await publicClient.getChainId(), 31337, "Local chain guard");
const wallet = createWalletClient({ chain: foundry, transport: http(rpc) });
const [owner, operator, recipient, stranger] = await wallet.getAddresses();
if (!owner || !operator || !recipient || !stranger)
  throw new Error("Start Anvil with its default unlocked local accounts");
const ownerWallet = createWalletClient({
  account: owner,
  chain: foundry,
  transport: http(rpc),
});
const operatorWallet = createWalletClient({
  account: operator,
  chain: foundry,
  transport: http(rpc),
});
const artifact = JSON.parse(
  readFileSync("out/ResourceAccounts.sol/ResourceAccounts.json", "utf8"),
);
async function confirmed(hash: Hex) {
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  assert.equal(receipt.status, "success");
  return receipt;
}
const deployed = await confirmed(
  await ownerWallet.deployContract({
    abi: resourceAccountsAbi,
    bytecode: artifact.bytecode.object as Hex,
  }),
);
assert.ok(deployed.contractAddress);
const address = deployed.contractAddress as Address;
const ownerSdk = resourceAccounts(publicClient, ownerWallet, address);
const operatorSdk = resourceAccounts(publicClient, operatorWallet, address);
const created = await confirmed(
  await ownerSdk.create("ipfs://local-intelio-app", {
    requestLimit: toWei("0.01"),
    dailyLimit: toWei("0.02"),
    lifetimeLimit: toWei("0.05"),
  }),
);
const [event] = parseEventLogs({
  abi: resourceAccountsAbi,
  logs: created.logs,
  eventName: "ApplicationCreated",
});
assert.ok(event);
const appId = event.args.appId;
const service = keccak256(toHex("classification-local"));
const request = keccak256(toHex("request-local-1"));
await confirmed(
  await ownerSdk.configure(appId, service, operator, recipient, true),
);
await confirmed(await ownerSdk.fund(appId, toWei("0.1")));
const before = await publicClient.getBalance({ address: recipient });
async function rejected(
  account: Address,
  requestId: Hex,
  amount: bigint,
  expected: string,
) {
  await assert.rejects(
    publicClient.simulateContract({
      address,
      abi: resourceAccountsAbi,
      functionName: "payUsage",
      args: [appId, service, requestId, amount],
      account,
    }),
    (error: unknown) =>
      error instanceof Error && error.message.includes(expected),
  );
}
await rejected(stranger, request, 1n, "Unauthorized");
await rejected(operator, request, toWei("0.01") + 1n, "RequestLimitExceeded");
await confirmed(await operatorSdk.pay(appId, service, request, toWei("0.01")));
assert.equal(
  (await publicClient.getBalance({ address: recipient })) - before,
  toWei("0.01"),
);
assert.equal(await ownerSdk.receiptPaid(appId, request), true);
await rejected(operator, request, 1n, "RequestAlreadyPaid");
await confirmed(await ownerSdk.pause(appId, true));
await rejected(operator, keccak256(toHex("request-2")), 1n, "AccountPaused");
const state = await ownerSdk.read(appId);
assert.equal(state.balance, toWei("0.09"));
assert.equal(state.lifetimeSpent, toWei("0.01"));
await confirmed(await ownerSdk.withdraw(appId, owner, state.balance));
await confirmed(await ownerSdk.close(appId));
const final = await ownerSdk.read(appId);
assert.equal(final.balance, 0n);
assert.equal(final.closed, true);
assert.equal(
  await publicClient.readContract({
    address,
    abi: resourceAccountsAbi,
    functionName: "totalLiabilities",
  }),
  0n,
);
assert.equal(await publicClient.getBalance({ address }), 0n);
writeFileSync(
  "/tmp/intelio-local-deployment.json",
  JSON.stringify({ address, appId: appId.toString(), chainId: 31337 }),
);
console.log(
  "PASS: deployed → registered → authorized → funded → paid → paused → withdrawn → closed",
);
console.log(
  "PASS: unauthorized, request-limit, replay and paused charges rejected; wei conserved",
);
console.log("Local-only contract:", address);
