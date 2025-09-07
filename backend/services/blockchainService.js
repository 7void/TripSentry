const { Web3 } = require('web3');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

class BlockchainService {
  constructor() {
    console.log('\n=== BLOCKCHAIN SERVICE INITIALIZATION ===');
    this.web3 = new Web3(process.env.RPC_URL);
    this.contractAddress = process.env.CONTRACT_ADDRESS;
    this.chainId = parseInt(process.env.CHAIN_ID);
    this.contract = null;
    this.governmentAccount = null;
    
    console.log('RPC URL:', process.env.RPC_URL);
    console.log('Contract Address:', this.contractAddress);
    console.log('Chain ID:', this.chainId);
    
    this.initialize();
  }

  async initialize() {
    try {
      console.log('Step 1: Loading contract ABI...');
      // Load contract ABI
      const abiPath = path.join(__dirname, '../../assets/contracts/TouristID.json');
      console.log('ABI Path:', abiPath);
      
      if (!fs.existsSync(abiPath)) {
        throw new Error(`Contract ABI file not found at: ${abiPath}`);
      }
      
      const contractABI = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
      console.log('ABI loaded successfully, methods count:', contractABI.length);
      
      console.log('Step 2: Initializing contract...');
      // Initialize contract
      this.contract = new this.web3.eth.Contract(contractABI, this.contractAddress);
      console.log('Contract initialized');
      
      console.log('Step 3: Setting up government account...');
      // Initialize government account
      const privateKey = process.env.GOVERNMENT_PRIVATE_KEY;
      if (!privateKey) {
        throw new Error('GOVERNMENT_PRIVATE_KEY not found in environment variables');
      }
      
      // Ensure private key has 0x prefix
      const formattedPrivateKey = privateKey.startsWith('0x') ? privateKey : '0x' + privateKey;
      console.log('Private key length:', formattedPrivateKey.length);
      
      this.governmentAccount = this.web3.eth.accounts.privateKeyToAccount(formattedPrivateKey);
      this.web3.eth.accounts.wallet.add(this.governmentAccount);
      console.log('Government account address:', this.governmentAccount.address);
      
      console.log('Step 4: Testing connection...');
      // Test connection
      await this.testConnection();
      
      console.log('=== BLOCKCHAIN SERVICE READY ===');
      logger.info('Blockchain service initialized', {
        contractAddress: this.contractAddress,
        governmentAddress: this.governmentAccount.address,
        chainId: this.chainId
      });
      
    } catch (error) {
      console.error('=== BLOCKCHAIN SERVICE INIT FAILED ===');
      console.error('Error:', error.message);
      console.error('Stack:', error.stack);
      console.log('==========================================\n');
      
      logger.error('Failed to initialize blockchain service', {
        error: error.message,
        stack: error.stack
      });
      throw error;
    }
  }

  async testConnection() {
    try {
      console.log('Testing blockchain connection...');
      
      const blockNumber = await this.web3.eth.getBlockNumber();
      console.log('Current block number:', Number(blockNumber));
      
      const balance = await this.web3.eth.getBalance(this.governmentAccount.address);
      const balanceEth = this.web3.utils.fromWei(balance, 'ether');
      console.log('Government account balance:', balanceEth, 'ETH');
      
      // Test contract connection
      try {
        const contractTest = await this.contract.methods.name().call();
        console.log('Contract name:', contractTest);
      } catch (contractError) {
        console.warn('Could not call contract name() method:', contractError.message);
      }
      
      logger.info('Blockchain connection test successful', {
        blockNumber: Number(blockNumber),
        governmentBalance: balanceEth
      });
      
      if (Number(balance) === 0) {
        console.warn('WARNING: Government account has zero balance - transactions will fail');
        logger.warn('Government account has zero balance - transactions may fail');
      }
    } catch (error) {
      console.error('Blockchain connection test failed:', error.message);
      logger.error('Blockchain connection test failed', { error: error.message });
      throw new Error('Failed to connect to blockchain network');
    }
  }

  async mintTouristID({
    touristAddress,
    touristIdHash,
    validUntil,
    metadataCID,
    issuerInfo = 'Government Tourism Authority'
  }) {
    const mintStartTime = Date.now();
    console.log('\n=== STARTING NFT MINT PROCESS ===');
    console.log('Mint Start Time:', new Date().toISOString());
    
    try {
      console.log('=== INPUT VALIDATION ===');
      // Validate inputs
      if (!this.web3.utils.isAddress(touristAddress)) {
        throw new Error('Invalid tourist address');
      }
      console.log('✓ Tourist address valid:', touristAddress);

      if (!touristIdHash || touristIdHash.length !== 66) {
        throw new Error('Invalid tourist ID hash - must be 66 characters including 0x prefix');
      }
      console.log('✓ Tourist ID hash valid:', touristIdHash);

      if (!metadataCID || metadataCID.length === 0) {
        throw new Error('Invalid metadata CID');
      }
      console.log('✓ Metadata CID valid:', metadataCID);

      // Convert validUntil to Unix timestamp
      const validUntilTimestamp = Math.floor(validUntil.getTime() / 1000);
      console.log('Valid until timestamp:', validUntilTimestamp);
      
      if (validUntilTimestamp <= Math.floor(Date.now() / 1000)) {
        throw new Error('Valid until date must be in the future');
      }
      console.log('✓ Valid until date is in future');

      console.log('=== ACCOUNT BALANCE CHECK ===');
      // Check government account balance
      const balance = await this.web3.eth.getBalance(this.governmentAccount.address);
      const balanceEth = this.web3.utils.fromWei(balance, 'ether');
      console.log('Government balance:', balanceEth, 'ETH');
      
      if (Number(balance) === 0) {
        throw new Error('Government account has insufficient balance for gas fees');
      }

      console.log('=== EXISTING ID CHECK ===');
      // Check if tourist already has an active ID
      try {
        const hasActiveId = await this.contract.methods.hasActiveTouristID(touristAddress).call();
        console.log('Tourist has active ID:', hasActiveId);
        if (hasActiveId) {
          throw new Error('Tourist already has an active ID');
        }
      } catch (contractError) {
        console.warn('Could not check existing tourist ID:', contractError.message);
      }

      console.log('=== CONTRACT CALL SIMULATION ===');
      // First, try to call the function to make sure it won't revert
      try {
        const callResult = await this.contract.methods.mintTouristID(
          touristAddress,
          touristIdHash,
          validUntilTimestamp,
          metadataCID,
          issuerInfo
        ).call({ from: this.governmentAccount.address });
        
        console.log('✓ Contract call simulation successful, result:', callResult);
      } catch (callError) {
        console.error('✗ Contract call simulation failed:', callError.message);
        console.error('Call error details:', callError);
        throw new Error(`Contract call would fail: ${callError.message}`);
      }

      console.log('=== GAS ESTIMATION ===');
      // Estimate gas with error handling and buffer
      let gasEstimate;
      try {
        gasEstimate = await this.contract.methods.mintTouristID(
          touristAddress,
          touristIdHash,
          validUntilTimestamp,
          metadataCID,
          issuerInfo
        ).estimateGas({
          from: this.governmentAccount.address
        });
        
        // Add 50% buffer to gas estimate
        gasEstimate = Math.floor(Number(gasEstimate) * 1.5);
        console.log('✓ Gas estimation successful:', gasEstimate);
      } catch (gasError) {
        console.error('✗ Gas estimation failed:', gasError.message);
        console.error('Gas error details:', gasError);
        // Fallback gas limit
        gasEstimate = 500000;
        console.warn('Using fallback gas estimate:', gasEstimate);
      }

      console.log('=== GAS PRICE FETCH ===');
      // Get current gas price with fallback
      let gasPrice;
      try {
        gasPrice = await this.web3.eth.getGasPrice();
        // Add 20% buffer to gas price for faster confirmation
        gasPrice = Math.floor(Number(gasPrice) * 1.2);
        console.log('✓ Current gas price:', gasPrice);
      } catch (gasPriceError) {
        console.error('✗ Gas price fetch failed:', gasPriceError.message);
        gasPrice = this.web3.utils.toWei('20', 'gwei'); // Fallback gas price
        console.warn('Using fallback gas price:', gasPrice);
      }

      console.log('=== TRANSACTION PREPARATION ===');
      // Prepare transaction data
      const mintData = this.contract.methods.mintTouristID(
        touristAddress,
        touristIdHash,
        validUntilTimestamp,
        metadataCID,
        issuerInfo
      ).encodeABI();
      console.log('Contract data encoded, length:', mintData.length);

      // Get current nonce
      const nonce = await this.web3.eth.getTransactionCount(this.governmentAccount.address, 'pending');
      console.log('Current nonce:', nonce);

      // Create transaction
      const transaction = {
        from: this.governmentAccount.address,
        to: this.contractAddress,
        data: mintData,
        gas: gasEstimate,
        gasPrice: gasPrice.toString(),
        chainId: this.chainId,
        nonce: nonce
      };

      console.log('Transaction object:', {
        from: transaction.from,
        to: transaction.to,
        gas: transaction.gas,
        gasPrice: transaction.gasPrice,
        chainId: transaction.chainId,
        nonce: transaction.nonce,
        dataLength: transaction.data.length
      });

      console.log('=== SENDING TRANSACTION ===');
      console.log('Transaction send time:', new Date().toISOString());
      
      // Send transaction with extended timeout (5 minutes)
      const receipt = await Promise.race([
        this.web3.eth.sendTransaction(transaction),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Transaction timeout after 5 minutes')), 300000)
        )
      ]);

      console.log('✓ Transaction sent successfully!');
      console.log('Transaction hash:', receipt.transactionHash);
      console.log('Block number:', receipt.blockNumber);

      console.log('=== WAITING FOR CONFIRMATION ===');
      // Wait for confirmation with extended timeout (7 minutes)
      const txReceipt = await Promise.race([
        this.waitForTransactionReceipt(receipt.transactionHash, 120, 3500), // 120 attempts, 3.5s interval
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Receipt timeout after 7 minutes')), 420000)
        )
      ]);

      if (!txReceipt || !txReceipt.status) {
        console.error('Transaction failed or reverted');
        console.error('Receipt status:', txReceipt?.status);
        console.error('Receipt:', txReceipt);
        throw new Error(`Transaction failed: ${txReceipt ? 'Reverted' : 'No receipt'}`);
      }

      console.log('✓ Transaction confirmed successfully!');
      console.log('Final receipt:', {
        transactionHash: txReceipt.transactionHash,
        blockNumber: txReceipt.blockNumber,
        gasUsed: Number(txReceipt.gasUsed),
        status: txReceipt.status,
        logsCount: txReceipt.logs.length
      });

      console.log('=== TOKEN ID EXTRACTION ===');
      // Extract token ID from transaction receipt
      const tokenId = await this.getTokenIdFromMintEvent(txReceipt);

      const totalTime = Date.now() - mintStartTime;
      console.log('=== MINT COMPLETED SUCCESSFULLY ===');
      console.log('Total processing time:', totalTime, 'ms');
      console.log('Transaction hash:', receipt.transactionHash);
      console.log('Token ID:', tokenId);
      console.log('Block number:', txReceipt.blockNumber);
      console.log('Gas used:', Number(txReceipt.gasUsed));
      console.log('====================================\n');

      logger.info('Tourist ID minted successfully', {
        transactionHash: receipt.transactionHash,
        tokenId,
        blockNumber: txReceipt.blockNumber,
        gasUsed: Number(txReceipt.gasUsed),
        processingTime: totalTime
      });

      return {
        transactionHash: receipt.transactionHash,
        tokenId,
        blockNumber: Number(txReceipt.blockNumber),
        gasUsed: Number(txReceipt.gasUsed)
      };

    } catch (error) {
      const totalTime = Date.now() - mintStartTime;
      console.error('\n=== MINT PROCESS FAILED ===');
      console.error('Total processing time:', totalTime, 'ms');
      console.error('Error type:', error.constructor.name);
      console.error('Error message:', error.message);
      console.error('Error stack:', error.stack);
      
      // Log additional error properties
      if (error.code) console.error('Error code:', error.code);
      if (error.reason) console.error('Error reason:', error.reason);
      if (error.data) console.error('Error data:', error.data);
      if (error.transaction) console.error('Transaction data:', error.transaction);
      
      console.log('==============================\n');
      
      logger.error('Error minting Tourist ID', {
        error: error.message,
        stack: error.stack,
        touristAddress,
        touristIdHash,
        metadataCID,
        processingTime: totalTime
      });
      throw error;
    }
  }

  async waitForTransactionReceipt(txHash, maxAttempts = 120, interval = 3500) {
    console.log(`Waiting for transaction receipt: ${txHash}`);
    console.log(`Max attempts: ${maxAttempts}, Interval: ${interval}ms`);
    
    for (let i = 0; i < maxAttempts; i++) {
      try {
        const receipt = await this.web3.eth.getTransactionReceipt(txHash);
        if (receipt) {
          console.log(`✓ Receipt received on attempt ${i + 1}`);
          console.log('Receipt details:', {
            blockNumber: receipt.blockNumber,
            status: receipt.status,
            gasUsed: Number(receipt.gasUsed)
          });
          return receipt;
        }
      } catch (error) {
        console.warn(`Attempt ${i + 1} to get receipt failed:`, error.message);
      }
      
      await new Promise(resolve => setTimeout(resolve, interval));
      console.log(`Waiting for confirmation... (${i + 1}/${maxAttempts})`);
    }
    
    throw new Error('Transaction receipt not found after maximum attempts');
  }

  async getTokenIdFromMintEvent(txReceipt) {
    try {
      console.log('=== TOKEN ID EXTRACTION ===');
      console.log('Transaction logs count:', txReceipt.logs.length);
      console.log('Transaction hash:', txReceipt.transactionHash);
      
      // Log all events for debugging
      txReceipt.logs.forEach((log, index) => {
        console.log(`Log ${index}:`, {
          address: log.address,
          topics: log.topics,
          data: log.data
        });
      });

      // Try to find the Transfer event (ERC721 standard)
      for (const log of txReceipt.logs) {
        try {
          // Transfer event signature: Transfer(address,address,uint256)
          const transferEventSignature = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
          
          console.log('Checking log for Transfer event...');
          console.log('Log address:', log.address);
          console.log('Contract address:', this.contractAddress);
          console.log('Topic[0]:', log.topics[0]);
          console.log('Expected signature:', transferEventSignature);
          
          if (log.topics[0] === transferEventSignature && log.address.toLowerCase() === this.contractAddress.toLowerCase()) {
            console.log('Found Transfer event!');
            // For Transfer events: topics[1] = from, topics[2] = to, topics[3] = tokenId
            if (log.topics.length >= 4) {
              const tokenId = this.web3.utils.hexToNumber(log.topics[3]);
              console.log('✓ Token ID extracted from Transfer event:', tokenId);
              return tokenId;
            } else {
              console.log('Transfer event found but insufficient topics:', log.topics.length);
            }
          }
        } catch (decodeError) {
          console.warn('Failed to decode log:', decodeError.message);
          continue;
        }
      }

      console.log('No Transfer event found, trying TouristIDMinted event...');
      
      // Try to find TouristIDMinted event as fallback
      for (const log of txReceipt.logs) {
        try {
          if (log.address.toLowerCase() === this.contractAddress.toLowerCase()) {
            console.log('Trying to decode custom TouristIDMinted event...');
            
            // Try to decode with contract ABI
            const decodedLog = this.web3.eth.abi.decodeLog(
              [
                { "indexed": true, "internalType": "uint256", "name": "tokenId", "type": "uint256" },
                { "indexed": true, "internalType": "bytes32", "name": "touristIdHash", "type": "bytes32" },
                { "indexed": true, "internalType": "address", "name": "tourist", "type": "address" },
                { "indexed": false, "internalType": "uint256", "name": "validUntil", "type": "uint256" },
                { "indexed": false, "internalType": "string", "name": "metadataCID", "type": "string" }
              ],
              log.data,
              log.topics
            );
            
            if (decodedLog.tokenId) {
              const tokenId = Number(decodedLog.tokenId);
              console.log('✓ Token ID extracted from TouristIDMinted event:', tokenId);
              return tokenId;
            }
          }
        } catch (decodeError) {
          console.warn('Failed to decode custom event log:', decodeError.message);
          continue;
        }
      }

      console.log('No token ID found in events, trying contract call...');
      
      // Try to get current token ID from contract
      try {
        const currentTokenId = await this.contract.methods.getCurrentTokenId().call();
        const tokenId = Number(currentTokenId);
        console.log('✓ Current token ID from contract:', tokenId);
        return tokenId;
      } catch (contractError) {
        console.error('Failed to get current token ID from contract:', contractError.message);
        
        // Final fallback: return 0 and let the caller handle it
        console.warn('Using fallback token ID of 0');
        return 0;
      }
      
    } catch (error) {
      console.error('Error extracting token ID:', error.message);
      console.error('Error stack:', error.stack);
      // Don't throw error, return fallback
      return 0;
    }
  }

  async getTouristRecord(tokenId) {
    try {
      console.log(`Getting tourist record for token ID: ${tokenId}`);
      const result = await this.contract.methods.getTouristRecord(tokenId).call();
      
      const record = {
        tokenId,
        touristIdHash: result[0],
        metadataCID: result[1],
        validUntil: new Date(parseInt(result[2]) * 1000),
        isActive: result[3],
        touristAddress: result[4],
        issuedAt: new Date(parseInt(result[5]) * 1000),
        issuerInfo: result[6]
      };
      
      console.log('Tourist record retrieved:', record);
      return record;
    } catch (error) {
      console.error('Error getting tourist record:', error.message);
      return null; // Return null instead of throwing
    }
  }

  // Added missing getAllActiveTouristIDs method
  async getAllActiveTouristIDs(page = 1, limit = 50) {
    try {
      console.log(`Getting all active tourist IDs - Page: ${page}, Limit: ${limit}`);
      
      // Get all active tourist IDs from contract
      const result = await this.contract.methods.getAllActiveTouristIDs().call();
      const tokenIds = result[0] || [];
      const tourists = result[1] || [];
      
      console.log(`Found ${tokenIds.length} active tourist IDs`);
      
      // Apply pagination
      const startIndex = (page - 1) * limit;
      const endIndex = startIndex + limit;
      
      const paginatedTokenIds = tokenIds.slice(startIndex, endIndex);
      const paginatedTourists = tourists.slice(startIndex, endIndex);
      
      console.log(`Returning ${paginatedTokenIds.length} paginated results`);
      
      // Get detailed records for paginated results
      const records = [];
      for (let i = 0; i < paginatedTokenIds.length; i++) {
        try {
          const record = await this.getTouristRecord(Number(paginatedTokenIds[i]));
          if (record) {
            records.push(record);
          }
        } catch (error) {
          console.warn(`Failed to get record for token ID ${paginatedTokenIds[i]}:`, error.message);
        }
      }
      
      return {
        records,
        pagination: {
          page,
          limit,
          total: tokenIds.length,
          totalPages: Math.ceil(tokenIds.length / limit)
        }
      };
    } catch (error) {
      console.error('Error getting all active tourist IDs:', error.message);
      throw error;
    }
  }

  async isValidTouristID(tokenId) {
    try {
      console.log(`Checking if tourist ID is valid: ${tokenId}`);
      const result = await this.contract.methods.isValidTouristID(tokenId).call();
      console.log(`Tourist ID ${tokenId} is valid:`, result);
      return result;
    } catch (error) {
      console.error('Error checking if tourist ID is valid:', error.message);
      return false; // Return false instead of throwing
    }
  }

  async getGovernmentBalance() {
    try {
      const balance = await this.web3.eth.getBalance(this.governmentAccount.address);
      const balanceEth = this.web3.utils.fromWei(balance, 'ether');
      console.log('Government balance:', balanceEth, 'ETH');
      return balanceEth;
    } catch (error) {
      console.error('Error getting government balance:', error.message);
      throw error;
    }
  }
}

module.exports = new BlockchainService();