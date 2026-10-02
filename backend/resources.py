"""Read an application resource account without a private key."""
import json, os
from pathlib import Path
from dotenv import load_dotenv
from web3 import Web3
root = Path(__file__).resolve().parents[1]
load_dotenv(root / '.env')
w3 = Web3(Web3.HTTPProvider(os.environ['RH_RPC_URL']))
if w3.eth.chain_id != int(os.getenv('CHAIN_ID', '46630')):
    raise RuntimeError('Wrong network')
address = Web3.to_checksum_address(os.environ['CONTRACT_ADDRESS'])
if not w3.eth.get_code(address):
    raise RuntimeError('Contract is not deployed')
abi = json.loads((root / 'web/abi.json').read_text())
c = w3.eth.contract(address=address, abi=abi)
owner, metadata, balance = c.functions.applications(int(os.getenv('APP_ID', '1'))).call()
print(json.dumps(dict(owner=owner, metadata=metadata, balance_wei=str(balance)), indent=2))
