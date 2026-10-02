import {ethers, artifacts} from 'hardhat';
import {mkdir, writeFile} from 'node:fs/promises';
import path from 'node:path';

async function main() {
  const [deployer] = await ethers.getSigners();
  if (!deployer) throw Error('Set DEPLOYER_PRIVATE_KEY in the root .env for testnet deployment');
  const contract = await (await ethers.getContractFactory('IntelioResources')).deploy();
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  const {chainId} = await ethers.provider.getNetwork();
  const {abi} = await artifacts.readArtifact('IntelioResources');
  const publicDir = path.resolve(__dirname, '../../web');
  await mkdir(publicDir, {recursive: true});
  await writeFile(path.join(publicDir, 'config.js'), `window.INTELIO_CONFIG = ${JSON.stringify({address, chainId: Number(chainId), abi}, null, 2)};\n`);
  await mkdir(path.resolve(__dirname, '../deployments'), {recursive: true});
  await writeFile(path.resolve(__dirname, `../deployments/${chainId}.json`), JSON.stringify({address, chainId: Number(chainId), deployer: deployer.address}, null, 2));
  console.log('Deployed:', address, 'chain:', chainId.toString());
  console.log('Website config updated. Set CONTRACT_ADDRESS in the root .env for scripts.');
}
main().catch(error => {console.error(error); process.exitCode = 1;});
