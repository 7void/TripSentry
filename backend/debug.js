// Save this as backend/debug.js and run with: node debug.js
require('dotenv').config();
const { Web3 } = require('web3');
const fs = require('fs');
const path = require('path');

async function debugEnvironment() {
  console.log('\n=== ENVIRONMENT DEBUG REPORT ===');
  console.log('Timestamp:', new Date().toISOString());
  console.log('================================\n');
  
  // 1. Check Environment Variables
  console.log('1. ENVIRONMENT VARIABLES:');
  console.log('RPC_URL:', process.env.RPC_URL ? '✓ Set' : '✗ Missing');
  console.log('CONTRACT_ADDRESS:', process.env.CONTRACT_ADDRESS ? '✓ Set' : '✗ Missing');
  console.log('CHAIN_ID:', process.env.CHAIN_ID ? `✓ ${process.env.CHAIN_ID}` : '✗ Missing');
  console.log('GOVERNMENT_PRIVATE_KEY:', process.env.GOVERNMENT_PRIVATE_KEY ? '✓ Set' : '✗ Missing');
  console.log('PORT:', process.env.PORT || '3000 (default)');
  console.log('NODE_ENV:', process.env.NODE_ENV || 'development (default)');
  
  // 2. Check Contract ABI File
  console.log('\n2. CONTRACT ABI FILE:');
  const abiPath = path.join(__dirname, 'assets/contracts/TouristID.json');
  console.log('ABI Path:', abiPath);
  
  if (fs.existsSync(abiPath)) {
    console.log('✓ ABI file exists');
    try {
      const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
      console.log('✓ ABI file is valid JSON');
      console.log('ABI methods count:', abi.length);
      
      // Check for required methods
      const requiredMethods = ['mintTouristID', 'getTouristRecord', 'getCurrentTokenId'];
      requiredMethods.forEach(method => {
        const hasMethod = abi.some(item => item.name === method);
        console.log(`  ${method}:`, hasMethod ? '✓' : '✗');
      });
    } catch (error) {
      console.log('✗ ABI file is not valid JSON:', error.message);
    }
  } else {
    console.log('✗ ABI file not found');
  }
  
  // 3. Test Web3 Connection
  console.log('\n3. WEB3 CONNECTION:');
  if (!process.env.RPC_URL) {
    console.log('✗ Cannot test - RPC_URL not set');
  } else {
    try {
      const web3 = new Web3(process.env.RPC_URL);
      console.log('✓ Web3 instance created');
      
      const blockNumber = await web3.eth.getBlockNumber();
      console.log('✓ Connected to blockchain, current block:', Number(blockNumber));
      
      const chainId = await web3.eth.getChainId();
      console.log('✓ Chain ID from network:', Number(chainId));
      
      if (process.env.CHAIN_ID && Number(chainId) !== Number(process.env.CHAIN_ID)) {
        console.log('⚠️  WARNING: Chain ID mismatch!');
        console.log('   Expected:', process.env.CHAIN_ID);
        console.log('   Actual:', Number(chainId));
      }
      
    } catch (error) {
      console.log('✗ Web3 connection failed:', error.message);
    }
  }
  
  // 4. Test Government Account
  console.log('\n4. GOVERNMENT ACCOUNT:');
  if (!process.env.GOVERNMENT_PRIVATE_KEY) {
    console.log('✗ Cannot test - GOVERNMENT_PRIVATE_KEY not set');
  } else {
    try {
      const web3 = new Web3(process.env.RPC_URL);
      const privateKey = process.env.GOVERNMENT_PRIVATE_KEY.startsWith('0x') 
        ? process.env.GOVERNMENT_PRIVATE_KEY 
        : '0x' + process.env.GOVERNMENT_PRIVATE_KEY;
      
      console.log('Private key length:', privateKey.length, privateKey.length === 66 ? '✓' : '✗ Should be 66');
      
      const account = web3.eth.accounts.privateKeyToAccount(privateKey);
      console.log('✓ Government account created');
      console.log('Address:', account.address);
      
      const balance = await web3.eth.getBalance(account.address);
      const balanceEth = web3.utils.fromWei(balance, 'ether');
      console.log('Balance:', balanceEth, 'ETH');
      
      if (Number(balance) === 0) {
        console.log('⚠️  WARNING: Government account has zero balance!');
      }
      
    } catch (error) {
      console.log('✗ Government account test failed:', error.message);
    }
  }
  
  // 5. Test Contract Connection
  console.log('\n5. CONTRACT CONNECTION:');
  if (!process.env.RPC_URL || !process.env.CONTRACT_ADDRESS) {
    console.log('✗ Cannot test - Missing RPC_URL or CONTRACT_ADDRESS');
  } else {
    try {
      const web3 = new Web3(process.env.RPC_URL);
      const abiPath = path.join(__dirname, 'assets/contracts/TouristID.json');
      
      if (!fs.existsSync(abiPath)) {
        console.log('✗ Cannot test - ABI file not found');
      } else {
        const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
        const contract = new web3.eth.Contract(abi, process.env.CONTRACT_ADDRESS);
        console.log('✓ Contract instance created');
        
        // Test contract methods
        try {
          const name = await contract.methods.name().call();
          console.log('✓ Contract name():', name);
        } catch (error) {
          console.log('✗ Contract name() failed:', error.message);
        }
        
        try {
          const symbol = await contract.methods.symbol().call();
          console.log('✓ Contract symbol():', symbol);
        } catch (error) {
          console.log('✗ Contract symbol() failed:', error.message);
        }
        
        try {
          const currentTokenId = await contract.methods.getCurrentTokenId().call();
          console.log('✓ Current token ID:', Number(currentTokenId));
        } catch (error) {
          console.log('✗ getCurrentTokenId() failed:', error.message);
        }
      }
    } catch (error) {
      console.log('✗ Contract connection failed:', error.message);
    }
  }
  
  // 6. Network Information
  console.log('\n6. NETWORK INFORMATION:');
  if (process.env.RPC_URL) {
    console.log('RPC URL:', process.env.RPC_URL);
    if (process.env.RPC_URL.includes('localhost') || process.env.RPC_URL.includes('127.0.0.1')) {
      console.log('⚠️  Using local network - ensure blockchain node is running');
    }
    if (process.env.RPC_URL.includes('infura') || process.env.RPC_URL.includes('alchemy')) {
      console.log('✓ Using public RPC provider');
    }
  }
  
  console.log('\n================================');
  console.log('Debug report completed');
  console.log('================================\n');
}

// Run the debug function
debugEnvironment().catch(console.error);