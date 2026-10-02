// Exercise the actual HTML/JavaScript controls against a disposable local chain.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {JSDOM} = require('jsdom');
const {JsonRpcProvider, Contract, parseEther} = require('ethers');
const dir = path.resolve(__dirname, '../../web');
async function waitFor(predicate) {
  const deadline = Date.now() + 15000;
  while (!predicate()) {
    if (Date.now() > deadline) throw Error('UI operation timed out');
    await new Promise(resolve => setTimeout(resolve, 50));
  }
}
async function main() {
  const dom = new JSDOM(fs.readFileSync(path.join(dir, 'index.html'), 'utf8'), {runScripts: 'outside-only', url: 'http://localhost:5173/onchain/index.html'});
  const window = dom.window;
  window.eval(fs.readFileSync(path.join(dir, 'vendor/ethers.umd.min.js'), 'utf8'));
  window.eval(fs.readFileSync(path.join(dir, 'config.js'), 'utf8'));
  const config = window.INTELIO_CONFIG;
  assert.equal(config.chainId, 31337, 'Only a disposable local deployment can be used');
  const provider = new JsonRpcProvider('http://127.0.0.1:8545');
  assert.equal((await provider.getNetwork()).chainId, 31337n);
  window.ethereum = {request: ({method, params}) => provider.send(method === 'eth_requestAccounts' ? 'eth_accounts' : method, params || []), on() {}};
  window.eval(fs.readFileSync(path.join(dir, 'app.js'), 'utf8'));
  const document = window.document;
  document.querySelector('#wallet-options button').click();
  await waitFor(() => document.getElementById('account').textContent.startsWith('Connected:'));
  const accounts = await provider.send('eth_accounts', []);
  function input(id, value) {document.getElementById(id).value = value;}
  async function submit(action) {
    const form = document.querySelector(`form[data-action="${action}"]`);
    form.dispatchEvent(new window.Event('submit', {bubbles: true, cancelable: true}));
    await waitFor(() => !form.querySelector('button').disabled);
    assert.match(document.getElementById('status').textContent, /^Confirmed:/);
  }
  input('metadata', 'ipfs://ui-smoke'); await submit('create');
  input('deposit-amount', '0.01'); await submit('deposit');
  input('operator', accounts[0]); input('allowance', '0.003'); await submit('operator');
  input('recipient', accounts[1]); await submit('recipient');
  input('pay-recipient', accounts[1]); input('pay-amount', '0.001'); input('receipt', 'ui-usage-1'); await submit('pay');
  input('withdraw-amount', '0.004'); await submit('withdraw');
  const contract = new Contract(config.address, config.abi, provider);
  const appId = BigInt(document.getElementById('app-id').value);
  assert.equal((await contract.applications(appId)).balance, parseEther('0.005'));
  assert.equal(await contract.operatorAllowance(appId, accounts[0]), parseEther('0.002'));
  console.log('UI smoke passed: connect, create, deposit, authorize, pay, withdraw, read');
  window.close(); provider.destroy();
}
main().catch(error => {console.error(error); process.exitCode = 1;});
