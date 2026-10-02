import {ethers} from 'hardhat';
import {expect} from 'chai';
describe('Intelio resource utility: Solidity behavioral scenarios', () => {
 for(let suite=0;suite<5;suite++) {
  it(`executes suite ${suite}`,async()=>{
   const c=await (await ethers.getContractFactory(`ResourceScenarios${suite}`)).deploy();
   await c.waitForDeployment();
   for(const f of c.interface.fragments) {
    if(f.type==='function' && 'name' in f && String(f.name).startsWith('test')) {
     const tx=await c.getFunction(String(f.name))({value:ethers.parseEther('1')});
     expect((await tx.wait())?.status,String(f.name)).to.equal(1);
    }
   }
  });
 }
});
