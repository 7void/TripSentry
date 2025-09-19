#!/usr/bin/env node
require('dotenv').config();
const path = require('path');
const fs = require('fs');
const Web3 = require('web3');

async function main() {
  const { RPC_URL, GOVERNMENT_PRIVATE_KEY, CONTRACT_BYTECODE } = process.env;
  if (!RPC_URL) throw new Error('RPC_URL missing');
  if (!GOVERNMENT_PRIVATE_KEY) throw new Error('GOVERNMENT_PRIVATE_KEY missing');
  if (!CONTRACT_BYTECODE) throw new Error('CONTRACT_BYTECODE missing');

  const web3 = new Web3(new Web3.providers.HttpProvider(RPC_URL));
  const pk = GOVERNMENT_PRIVATE_KEY.startsWith('0x') ? GOVERNMENT_PRIVATE_KEY : '0x' + GOVERNMENT_PRIVATE_KEY;
  const account = web3.eth.accounts.wallet.add(pk);
  console.log('Deploying from address:', account.address);

  const abiPath = path.join(__dirname, '..', 'assets', 'contracts', 'TouristID.json');
  const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));

  // Constructor has no params
  const contract = new web3.eth.Contract(abi);
  const deploy = contract.deploy({ data: '0x' + CONTRACT_BYTECODE });

  const gas = await deploy.estimateGas({ from: account.address });
  console.log('Estimated gas:', gas);

  const tx = await deploy.send({ from: account.address, gas });
  console.log('Contract deployed at:', tx.options.address);
  console.log('Add this to .env as CONTRACT_ADDRESS=');
  console.log(tx.options.address);
}

main().catch(err => {
  console.error('Deployment failed:', err);
  process.exit(1);
});
