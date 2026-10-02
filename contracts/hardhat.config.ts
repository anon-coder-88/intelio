import {HardhatUserConfig, subtask} from 'hardhat/config';
import {TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD} from 'hardhat/builtin-tasks/task-names';
import '@nomicfoundation/hardhat-ethers';
import '@nomicfoundation/hardhat-chai-matchers';
import dotenv from 'dotenv';
import path from 'node:path';
dotenv.config({path: path.resolve(__dirname, '../.env')});

// Use the pinned local compiler so compilation needs no remote compiler download.
subtask(TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD).setAction(async ({solcVersion}, _hre, runSuper) => {
  if (solcVersion !== '0.8.20') return runSuper();
  return {compilerPath: require.resolve('solc/soljson.js'), isSolcJs: true, version: solcVersion, longVersion: require('solc').version()};
});
const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
if (privateKey && !/^0x[0-9a-fA-F]{64}$/.test(privateKey)) throw Error('Invalid DEPLOYER_PRIVATE_KEY format');
const config: HardhatUserConfig = {
  solidity: {version: '0.8.20', settings: {optimizer: {enabled: true, runs: 200}, evmVersion: 'paris'}},
  networks: {
    localhost: {url: 'http://127.0.0.1:8545', chainId: 31337},
    robinhoodTestnet: {url: process.env.RH_RPC_URL || 'https://rpc.testnet.chain.robinhood.com', chainId: 46630, accounts: privateKey ? [privateKey] : []}
  }
};
export default config;
