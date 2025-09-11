const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const blockchainService = require('./services/blockchainService');
const logger = require('./utils/logger');
const { validateMintRequest } = require('./middleware/validation');
const { authenticateApiKey } = require('./middleware/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(compression());

// CORS configuration
app.use(cors({
  origin: process.env.NODE_ENV === 'production' 
    ? ['https://your-flutter-app-domain.com'] 
    : ['http://localhost:3000', 'http://127.0.0.1:3000', 'http://172.20.188.199:3000'],
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.'
  }
});
app.use(limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging with detailed information
app.use((req, res, next) => {
  console.log('\n=== NEW REQUEST ===');
  console.log(`Timestamp: ${new Date().toISOString()}`);
  console.log(`Method: ${req.method}`);
  console.log(`Path: ${req.path}`);
  console.log(`Query: ${JSON.stringify(req.query)}`);
  console.log(`Headers: ${JSON.stringify(req.headers)}`);
  if (req.body && Object.keys(req.body).length > 0) {
    console.log(`Body: ${JSON.stringify(req.body)}`);
  }
  console.log('===================\n');
  
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    query: req.query,
    hasBody: !!req.body && Object.keys(req.body).length > 0
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  console.log('Health check requested');
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Blockchain status check endpoint
app.get('/api/blockchain-status', authenticateApiKey, async (req, res) => {
  console.log('\n=== BLOCKCHAIN STATUS CHECK ===');
  try {
    console.log('Starting blockchain status check...');
    
    const balance = await blockchainService.getGovernmentBalance();
    console.log(`Government balance: ${balance} ETH`);
    
    const blockNumber = await blockchainService.web3.eth.getBlockNumber();
    console.log(`Current block number: ${Number(blockNumber)}`);
    
    console.log('Blockchain status check completed successfully');
    console.log('===============================\n');
    
    res.json({
      success: true,
      data: {
        governmentBalance: balance,
        currentBlockNumber: Number(blockNumber),
        contractAddress: blockchainService.contractAddress,
        chainId: blockchainService.chainId,
        governmentAddress: blockchainService.governmentAccount?.address || 'Not initialized'
      }
    });
  } catch (error) {
    console.error('Blockchain status check failed:', error);
    console.log('===============================\n');
    
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// API Routes
app.use('/api', authenticateApiKey);

// Mint Tourist ID endpoint with extensive debugging
app.post('/api/mint-id', validateMintRequest, async (req, res) => {
  const startTime = Date.now();
  console.log('\n=== MINT TOURIST ID REQUEST ===');
  console.log(`Start Time: ${new Date().toISOString()}`);
  
  try {
    const {
      touristAddress,
      touristIdHash,
      validUntil,
      metadataCID,
      issuerInfo = 'Government Tourism Authority'
    } = req.body;

    console.log('=== REQUEST VALIDATION ===');
    console.log(`Tourist Address: ${touristAddress}`);
    console.log(`Tourist ID Hash: ${touristIdHash}`);
    console.log(`Valid Until: ${validUntil}`);
    console.log(`Metadata CID: ${metadataCID}`);
    console.log(`Issuer Info: ${issuerInfo}`);

    // Validate inputs
    if (!touristAddress || !touristIdHash || !validUntil || !metadataCID) {
      console.error('Missing required fields:', { touristAddress, touristIdHash, validUntil, metadataCID });
      return res.status(400).json({
        success: false,
        error: 'Missing required fields'
      });
    }

    logger.info('Minting Tourist ID request received', {
      touristAddress,
      touristIdHash,
      validUntil,
      metadataCID
    });

    console.log('=== BLOCKCHAIN SERVICE CALL ===');
    console.log('Calling blockchainService.mintTouristID...');
    
    // Track each step of the minting process
    let currentStep = 'initialization';
    
    try {
      currentStep = 'blockchain_service_call';
      console.log(`Step: ${currentStep} - Starting mint process`);
      
      // Mint the NFT using the government wallet
      const result = await blockchainService.mintTouristID({
        touristAddress,
        touristIdHash,
        validUntil: new Date(validUntil),
        metadataCID,
        issuerInfo
      });

      currentStep = 'mint_completed';
      console.log(`Step: ${currentStep} - Mint process completed`);
      console.log('Mint Result:', JSON.stringify(result, null, 2));

      const processingTime = Date.now() - startTime;
      console.log(`=== MINT SUCCESS ===`);
      console.log(`Processing Time: ${processingTime}ms`);
      console.log(`Transaction Hash: ${result.transactionHash}`);
      console.log(`Token ID: ${result.tokenId}`);
      console.log(`Block Number: ${result.blockNumber}`);
      console.log(`Gas Used: ${result.gasUsed}`);
      console.log('===================\n');

      logger.info('Tourist ID minted successfully', {
        transactionHash: result.transactionHash,
        tokenId: result.tokenId,
        touristAddress,
        processingTime
      });

      res.json({
        success: true,
        data: {
          transactionHash: result.transactionHash,
          tokenId: result.tokenId,
          touristAddress,
          touristIdHash,
          validUntil,
          metadataCID,
          issuerInfo,
          blockNumber: result.blockNumber,
          gasUsed: result.gasUsed,
          processingTime
        }
      });

    } catch (blockchainError) {
      currentStep = 'blockchain_error';
      console.error(`=== BLOCKCHAIN ERROR at step: ${currentStep} ===`);
      console.error('Error Type:', blockchainError.constructor.name);
      console.error('Error Message:', blockchainError.message);
      console.error('Error Stack:', blockchainError.stack);
      
      // Additional error context
      if (blockchainError.code) {
        console.error('Error Code:', blockchainError.code);
      }
      if (blockchainError.reason) {
        console.error('Error Reason:', blockchainError.reason);
      }
      if (blockchainError.transaction) {
        console.error('Failed Transaction:', JSON.stringify(blockchainError.transaction, null, 2));
      }
      
      console.log('=====================================\n');
      throw blockchainError;
    }

  } catch (error) {
    const processingTime = Date.now() - startTime;
    
    console.error('\n=== MINT ERROR ===');
    console.error(`Processing Time: ${processingTime}ms`);
    console.error('Error Type:', error.constructor.name);
    console.error('Error Message:', error.message);
    console.error('Error Stack:', error.stack);
    
    // Log additional error properties
    if (error.code) console.error('Error Code:', error.code);
    if (error.reason) console.error('Error Reason:', error.reason);
    if (error.data) console.error('Error Data:', error.data);
    if (error.transaction) console.error('Transaction Data:', error.transaction);
    
    console.log('==================\n');

    logger.error('Error minting Tourist ID', {
      error: error.message,
      stack: error.stack,
      body: req.body,
      processingTime
    });

    // Determine appropriate error status and message
    let statusCode = 500;
    let errorMessage = 'Failed to mint Tourist ID';
    
    if (error.message.includes('timeout')) {
      statusCode = 408;
      errorMessage = 'Request timeout - blockchain operation took too long';
    } else if (error.message.includes('insufficient balance')) {
      statusCode = 402;
      errorMessage = 'Insufficient balance in government account';
    } else if (error.message.includes('nonce')) {
      statusCode = 409;
      errorMessage = 'Transaction nonce conflict - please try again';
    } else if (error.message.includes('gas')) {
      statusCode = 400;
      errorMessage = 'Gas estimation failed - check contract parameters';
    }

    res.status(statusCode).json({
      success: false,
      error: errorMessage,
      message: error.message,
      code: error.code || null,
      processingTime
    });
  }
});

// Get Tourist ID details
app.get('/api/tourist-id/:tokenId', async (req, res) => {
  console.log(`\n=== GET TOURIST ID: ${req.params.tokenId} ===`);
  
  try {
    const { tokenId } = req.params;
    console.log(`Fetching tourist ID: ${tokenId}`);
    
    const touristRecord = await blockchainService.getTouristRecord(parseInt(tokenId));
    console.log('Tourist Record Result:', touristRecord);
    
    if (!touristRecord) {
      console.log(`Tourist ID not found: ${tokenId}`);
      return res.status(404).json({
        success: false,
        error: 'Tourist ID not found'
      });
    }

    console.log('Tourist ID fetched successfully');
    console.log('=====================================\n');

    res.json({
      success: true,
      data: touristRecord
    });

  } catch (error) {
    console.error('Error fetching Tourist ID:', error);
    console.log('=====================================\n');
    
    logger.error('Error fetching Tourist ID', {
      error: error.message,
      tokenId: req.params.tokenId
    });

    res.status(500).json({
      success: false,
      error: 'Failed to fetch Tourist ID',
      message: error.message
    });
  }
});

// Get all active Tourist IDs (for admin use)
app.get('/api/tourist-ids', async (req, res) => {
  console.log('\n=== GET ALL TOURIST IDS ===');
  
  try {
    const { page = 1, limit = 50 } = req.query;
    console.log(`Page: ${page}, Limit: ${limit}`);
    
    const result = await blockchainService.getAllActiveTouristIDs(
      parseInt(page),
      parseInt(limit)
    );

    console.log('All Tourist IDs fetched successfully');
    console.log(`Records count: ${result.records?.length || 0}`);
    console.log('===============================\n');

    res.json({
      success: true,
      data: result
    });

  } catch (error) {
    console.error('Error fetching Tourist IDs:', error);
    console.log('===============================\n');
    
    logger.error('Error fetching Tourist IDs', {
      error: error.message
    });

    res.status(500).json({
      success: false,
      error: 'Failed to fetch Tourist IDs',
      message: error.message
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('\n=== UNHANDLED ERROR ===');
  console.error('Error:', error.message);
  console.error('Stack:', error.stack);
  console.error('Path:', req.path);
  console.error('Method:', req.method);
  console.log('=======================\n');
  
  logger.error('Unhandled error', {
    error: error.message,
    stack: error.stack,
    path: req.path,
    method: req.method
  });

  res.status(500).json({
    success: false,
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'production' 
      ? 'Something went wrong' 
      : error.message
  });
});

// 404 handler
app.use('*', (req, res) => {
  console.log(`404 - Endpoint not found: ${req.method} ${req.originalUrl}`);
  
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('\n=================================');
  console.log(`🚀 Tourist ID Backend Server`);
  console.log(`📡 Running on port ${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV}`);
  console.log(`⏰ Started at: ${new Date().toISOString()}`);
  console.log('=================================\n');
  
  logger.info(`Tourist ID Backend Server running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV}`);
});

module.exports = app;