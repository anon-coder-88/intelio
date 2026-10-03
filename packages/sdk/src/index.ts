import {
  type Address,
  type Hex,
  type PublicClient,
  type WalletClient,
  parseEther,
} from "viem";
import { resourceAccountsAbi } from "../../abi/index.js";

export type SpendingPolicy = {
  requestLimit: bigint;
  dailyLimit: bigint;
  lifetimeLimit: bigint;
};

/** Decimal ETH input to integer wei; scientific notation and excess precision are rejected. */
export function toWei(input: string): bigint {
  if (!/^(0|[1-9]\d*)(\.\d{1,18})?$/.test(input))
    throw new Error("Use nonnegative ETH with at most 18 decimals");
  return parseEther(input);
}

/** Typed helpers use the generated ABI. Callers must await successful transaction receipts. */
export function resourceAccounts(
  publicClient: PublicClient,
  wallet: WalletClient,
  address: Address,
) {
  if (!wallet.account) throw new Error("A wallet account is required");
  const base = {
    address,
    abi: resourceAccountsAbi,
    account: wallet.account,
    chain: wallet.chain,
  };
  return {
    read: (appId: bigint) =>
      publicClient.readContract({
        address,
        abi: resourceAccountsAbi,
        functionName: "application",
        args: [appId],
      }),
    create: (metadata: string, policy: SpendingPolicy) =>
      wallet.writeContract({
        ...base,
        functionName: "createApplication",
        args: [metadata, policy],
      }),
    fund: (appId: bigint, value: bigint) =>
      wallet.writeContract({
        ...base,
        functionName: "fund",
        args: [appId],
        value,
      }),
    configure: (
      appId: bigint,
      service: Hex,
      operator: Address,
      recipient: Address,
      enabled: boolean,
    ) =>
      wallet.writeContract({
        ...base,
        functionName: "configureService",
        args: [appId, service, operator, recipient, enabled],
      }),
    pay: (appId: bigint, service: Hex, request: Hex, amount: bigint) =>
      wallet.writeContract({
        ...base,
        functionName: "payUsage",
        args: [appId, service, request, amount],
      }),
    withdraw: (appId: bigint, recipient: Address, amount: bigint) =>
      wallet.writeContract({
        ...base,
        functionName: "withdraw",
        args: [appId, recipient, amount],
      }),
    pause: (appId: bigint, paused: boolean) =>
      wallet.writeContract({
        ...base,
        functionName: "setPaused",
        args: [appId, paused],
      }),
    policy: (appId: bigint, policy: SpendingPolicy) =>
      wallet.writeContract({
        ...base,
        functionName: "setPolicy",
        args: [appId, policy],
      }),
    metadata: (appId: bigint, metadata: string) =>
      wallet.writeContract({
        ...base,
        functionName: "setMetadata",
        args: [appId, metadata],
      }),
    close: (appId: bigint) =>
      wallet.writeContract({
        ...base,
        functionName: "closeApplication",
        args: [appId],
      }),
    receiptPaid: (appId: bigint, request: Hex) =>
      publicClient.readContract({
        address,
        abi: resourceAccountsAbi,
        functionName: "paidRequests",
        args: [appId, request],
      }),
  };
}
