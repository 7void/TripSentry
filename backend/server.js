require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');

const logger = require('./utils/logger');
const auth = require('./middleware/auth');
const { mintTouristIdRules, handleValidation } = require('./middleware/validation');
const blockchain = require('./services/blockchainService');
const { notifyNewTouristID } = require('./services/alertService');
const { initFirebase } = require('./services/firebase');

// Initialize Firebase (non-blocking)
initFirebase();

const app = express();

// Middleware stack
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: false }));
app.use(morgan('combined', { stream: logger.stream }));

// Rate limiting
const limiter = rateLimit({
	windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
	max: Number(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
	standardHeaders: true,
	legacyHeaders: false
});
app.use(limiter);

// Health check
app.get('/health', (req, res) => {
	res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Get blockchain status (made public to ease client resolution)
app.get('/api/blockchain-status', async (req, res) => {
	try {
		const rawChainId = await blockchain.web3.eth.getChainId();
		const rawBlockNumber = await blockchain.web3.eth.getBlockNumber();
		const balance = await blockchain.getGovernmentBalance();
		const governmentAddress = blockchain.getGovernmentAddress();
		const contractOwner = await blockchain.getContractOwner();
		res.json({
			chainId: typeof rawChainId === 'bigint' ? Number(rawChainId) : rawChainId,
			blockNumber: typeof rawBlockNumber === 'bigint' ? Number(rawBlockNumber) : rawBlockNumber,
			governmentBalanceETH: balance,
			contractAddress: process.env.CONTRACT_ADDRESS,
			governmentAddress,
			contractOwner
		});
	} catch (err) {
		logger.error('Blockchain status error: ' + err.message);
		res.status(500).json({ error: 'Failed to fetch blockchain status' });
	}
});

// Mint Tourist ID
app.post('/api/mint-id', auth, mintTouristIdRules, handleValidation, async (req, res) => {
	const { touristIdHash, rawTouristId, validUntil, metadataCID, issuerInfo } = req.body;
	try {
		const hashInput = touristIdHash || rawTouristId;
		const result = await blockchain.mintTouristID({
			touristIdHash: hashInput,
			validUntil: Number(validUntil),
			metadataCID,
			issuerInfo
		});

		// Fetch freshly minted record (may require small delay, but typically immediate)
		const record = await blockchain.getTouristRecord(result.tokenId);
		await notifyNewTouristID(record);
		res.status(201).json({ ...result, record });
	} catch (err) {
		logger.error('Mint error: ' + err.message, { stack: err.stack });
		res.status(400).json({ error: err.message });
	}
});

// Get Tourist ID by tokenId
app.get('/api/tourist-id/:tokenId', auth, async (req, res) => {
	try {
		const record = await blockchain.getTouristRecord(req.params.tokenId);
		res.json(record);
	} catch (err) {
		res.status(404).json({ error: err.message });
	}
});

// List active Tourist IDs with pagination
app.get('/api/tourist-ids', auth, async (req, res) => {
	const { page = 1, limit = 20 } = req.query;
	try {
		const data = await blockchain.getAllActiveTouristIDs(page, limit);
		res.json(data);
	} catch (err) {
		logger.error('List tourist IDs error: ' + err.message);
		res.status(500).json({ error: 'Failed to retrieve tourist IDs' });
	}
});

// Not found handler
app.use((req, res) => {
	res.status(404).json({ error: 'Not found' });
});

// Error handler
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
	logger.error('Unhandled error: ' + err.message, { stack: err.stack });
	res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
	logger.info(`Server listening on port ${PORT}`);
});

module.exports = app;

