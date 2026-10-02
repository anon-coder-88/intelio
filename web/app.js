/* Wallet-approved transactions only; keys never enter this page. */
const config = window.INTELIO_CONFIG;
const $ = id => document.getElementById(id);
const providers = new Map();
let selectedProvider, browser, signer, contract;
let busy = false;
const status = message => { $('status').textContent = message; };
const value = id => $(id).value.trim();
const appId = () => { const id = BigInt(value('app-id')); if (id < 1n) throw Error('Application ID must be positive'); return id; };
const address = id => { if (!ethers.isAddress(value(id))) throw Error('Enter a valid address'); return ethers.getAddress(value(id)); };
const amount = id => { const n = ethers.parseEther(value(id)); if (n < 0n) throw Error('Amount cannot be negative'); return n; };
function showProviders() {
  $('wallet-options').replaceChildren();
  const entries = [...providers.values()];
  if (window.ethereum && !entries.length) entries.push({info: {name: 'Browser wallet'}, provider: window.ethereum});
  for (const entry of entries) {
    const button = document.createElement('button'); button.type = 'button';
    if (entry.info.icon?.startsWith('data:image/')) {
      const image = document.createElement('img'); image.src = entry.info.icon; image.alt = ''; button.append(image);
    }
    button.append(document.createTextNode(entry.info.name));
    button.addEventListener('click', () => connect(entry.provider)); $('wallet-options').append(button);
  }
  if (!entries.length) $('account').textContent = 'No wallet detected. Open Intelio in an EVM wallet browser or install a wallet extension.';
}
window.addEventListener('eip6963:announceProvider', event => {
  const detail = event.detail;
  if (!detail?.info?.uuid || !detail.provider?.request) return;
  providers.set(detail.info.uuid, detail); showProviders();
});
window.dispatchEvent(new Event('eip6963:requestProvider'));
showProviders();
async function connect(provider) {
  try {
    selectedProvider = provider;
    browser = new ethers.BrowserProvider(provider);
    await browser.send('eth_requestAccounts', []);
    signer = await browser.getSigner();
    $('account').textContent = `Connected: ${await signer.getAddress()}`;
    status('Wallet connected. Read an application or submit an action.');
    provider.on?.('accountsChanged', () => { signer = undefined; contract = undefined; $('account').textContent = 'Account changed. Reconnect to continue.'; });
    provider.on?.('chainChanged', () => { browser = undefined; signer = undefined; contract = undefined; $('account').textContent = 'Network changed. Reconnect to continue.'; });
  } catch (error) { status(error.shortMessage || error.message); }
}
async function ready() {
  if (!signer || !browser) throw Error('Connect your wallet first');
  if (!ethers.isAddress(config.address)) throw Error('Contract is not configured. Deploy using contracts/scripts/deploy.ts');
  if (Number((await browser.getNetwork()).chainId) !== config.chainId) throw Error('Switch to the configured network and reconnect');
  if (await browser.getCode(config.address) === '0x') throw Error('No contract found at the configured address');
  contract = new ethers.Contract(config.address, config.abi, signer);
  return contract;
}
async function refresh() {
  const c = await ready(); const app = await c.applications(appId());
  if (app.owner === ethers.ZeroAddress) throw Error('Unknown application');
  const allowance = await c.operatorAllowance(appId(), await signer.getAddress());
  $('application').replaceChildren();
  for (const [label, text] of [['Owner', app.owner], ['Metadata URI', app.metadataURI], ['Balance · ETH', ethers.formatEther(app.balance)], ['Your operator allowance · ETH', ethers.formatEther(allowance)]]) {
    const dt = document.createElement('dt'); dt.textContent = label;
    const dd = document.createElement('dd'); dd.textContent = text; $('application').append(dt, dd);
  }
}
$('refresh').addEventListener('click', () => refresh().catch(error => status(error.shortMessage || error.message)));
$('switch-network').addEventListener('click', async () => {
  try {
    if (!selectedProvider) throw Error('Choose your wallet first');
    const chainId = ethers.toBeHex(config.chainId);
    try { await selectedProvider.request({method: 'wallet_switchEthereumChain', params: [{chainId}]}); }
    catch (error) {
      if (error.code !== 4902 || config.chainId !== 46630) throw error;
      await selectedProvider.request({method: 'wallet_addEthereumChain', params: [{chainId, chainName: 'Robinhood Chain Testnet', nativeCurrency: {name: 'Ether', symbol: 'ETH', decimals: 18}, rpcUrls: ['https://rpc.testnet.chain.robinhood.com'], blockExplorerUrls: ['https://explorer.testnet.chain.robinhood.com']}]});
    }
    status('Network selected. Reconnect your wallet to continue.');
  } catch (error) { status(error.shortMessage || error.message); }
});
document.querySelectorAll('form[data-action]').forEach(form => form.addEventListener('submit', async event => {
  event.preventDefault(); if (busy) return;
  busy = true; document.querySelectorAll('button').forEach(button => {button.disabled = true;});
  try {
    const c = await ready(); let tx;
    switch (form.dataset.action) {
      case 'create': tx = await c.createApplication(value('metadata')); break;
      case 'deposit': tx = await c.deposit(appId(), {value: amount('deposit-amount')}); break;
      case 'operator': tx = await c.setOperator(appId(), address('operator'), amount('allowance')); break;
      case 'recipient': tx = await c.setRecipient(appId(), address('recipient'), value('approved') === 'true'); break;
      case 'pay': tx = await c.payUsage(appId(), address('pay-recipient'), amount('pay-amount'), ethers.id(value('receipt'))); break;
      case 'withdraw': tx = await c.withdraw(appId(), amount('withdraw-amount')); break;
      default: throw Error('Unknown action');
    }
    status(`Waiting for confirmation: ${tx.hash}`);
    const receipt = await tx.wait();
    if (form.dataset.action === 'create') {
      for (const log of receipt.logs) {
        try { const parsed = c.interface.parseLog(log); if (parsed?.name === 'ApplicationCreated') $('app-id').value = parsed.args.appId.toString(); } catch {}
      }
    }
    await refresh(); status(`Confirmed: ${tx.hash}`);
  } catch (error) { status(error.shortMessage || error.message); }
  finally {busy = false; document.querySelectorAll('button').forEach(button => {button.disabled = false;});}
}));
$('deployment').textContent = config.address ? `Contract: ${config.address} · chain ${config.chainId}` : 'Contract address not configured yet. Run the deployment script.';
