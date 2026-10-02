import {artifacts} from 'hardhat';
import {writeFileSync,existsSync} from 'node:fs';
const target='../web/config.js';
async function main() {
 const {abi}=await artifacts.readArtifact('IntelioResources');
 writeFileSync('../web/abi.json',JSON.stringify(abi));
 if(!existsSync(target)) writeFileSync(target,'window.INTELIO_CONFIG = '+JSON.stringify({address:'',chainId:46630,abi})+';');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
