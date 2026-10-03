import { createPublicClient, http, isAddress, formatEther } from "viem";
import { foundry } from "viem/chains";
import { resourceAccountsAbi } from "../../../packages/abi/index.js";
import "./style.css";

const field = (id: string) => document.getElementById(id) as HTMLInputElement;
const status = document.getElementById("status")!;
const state = document.getElementById("state")!;
const button = document.querySelector("button")!;
const client = createPublicClient({
  chain: foundry,
  transport: http("http://127.0.0.1:8545", { timeout: 5000, retryCount: 0 }),
});
document
  .getElementById("read-form")!
  .addEventListener("submit", async (event) => {
    event.preventDefault();
    if (button.disabled) return;
    button.disabled = true;
    state.replaceChildren();
    status.textContent = "Reading local chain…";
    try {
      const address = field("contract").value.trim();
      const id = field("app").value.trim();
      if (!isAddress(address) || !/^[1-9]\d*$/.test(id))
        throw new Error(
          "Enter a valid address and positive integer application ID",
        );
      if ((await client.getChainId()) !== 31337)
        throw new Error("Expected local chain 31337");
      if (!(await client.getCode({ address })))
        throw new Error("No contract at this local address");
      const app = await client.readContract({
        address,
        abi: resourceAccountsAbi,
        functionName: "application",
        args: [BigInt(id)],
      });
      const rows = {
        Owner: app.owner,
        "Public metadata": app.metadataURI,
        "Funded balance · ETH": formatEther(app.balance),
        "Lifetime charges · ETH": formatEther(app.lifetimeSpent),
        "Request limit · ETH": formatEther(app.policy.requestLimit),
        "Daily limit · ETH": formatEther(app.policy.dailyLimit),
        "Lifetime limit · ETH": formatEther(app.policy.lifetimeLimit),
        State: app.closed ? "Closed" : app.paused ? "Paused" : "Open",
      };
      for (const [label, value] of Object.entries(rows)) {
        const term = document.createElement("dt");
        term.textContent = label;
        const detail = document.createElement("dd");
        detail.textContent = value;
        state.append(term, detail);
      }
      status.textContent =
        "Local chain read completed at " + new Date().toISOString();
    } catch (error) {
      status.textContent =
        error instanceof Error ? error.message : "Read unavailable";
    } finally {
      button.disabled = false;
    }
  });
