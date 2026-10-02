import {ethers} from 'hardhat';

async function main() {
  const address = process.env.CONTRACT_ADDRESS;
  if (!address || !ethers.isAddress(address)) throw Error('Set CONTRACT_ADDRESS in .env');
  const action = process.env.ACTION || 'read';
  const appId = BigInt(process.env.APP_ID || '1');
  const contract = await ethers.getContractAt('IntelioResources', address);
  if (action === 'read') {
    const app = await contract.applications(appId);
    console.log({owner: app.owner, metadataURI: app.metadataURI, balanceETH: ethers.formatEther(app.balance)});
    return;
  }
  const [signer] = await ethers.getSigners();
  if (!signer) throw Error('Set DEPLOYER_PRIVATE_KEY for write actions');
  const amount = () => ethers.parseEther(process.env.AMOUNT_ETH || '0');
  const required = (name: string) => {const value = process.env[name]; if (!value) throw Error(`Set ${name}`); return value;};
  let tx;
  switch (action) {
    case 'create': tx = await contract.createApplication(required('METADATA_URI')); break;
    case 'deposit': tx = await contract.deposit(appId, {value: amount()}); break;
    case 'operator': tx = await contract.setOperator(appId, required('OPERATOR_ADDRESS'), amount()); break;
    case 'recipient': tx = await contract.setRecipient(appId, required('RECIPIENT_ADDRESS'), process.env.RECIPIENT_APPROVED === 'true'); break;
    case 'pay': tx = await contract.payUsage(appId, required('RECIPIENT_ADDRESS'), amount(), ethers.id(required('RECEIPT_REFERENCE'))); break;
    case 'withdraw': tx = await contract.withdraw(appId, amount()); break;
    default: throw Error('Unknown ACTION');
  }
  console.log('Transaction:', tx.hash);
  await tx.wait();
  console.log('Confirmed');
}
main().catch(error => {console.error(error); process.exitCode = 1;});
