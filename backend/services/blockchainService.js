const path = require('path');
const fs = require('fs');
// Web3 v4 exports named Web3 class
const { Web3 } = require('web3');
const logger = require('../utils/logger');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

// Load environment variables
const {
	RPC_URL,
	CONTRACT_ADDRESS,
	GOVERNMENT_PRIVATE_KEY,
	GOVERNMENT_ADDRESS,
	CHAIN_ID
} = process.env;

if (!RPC_URL) throw new Error('RPC_URL is not set in environment');
if (!GOVERNMENT_PRIVATE_KEY) logger.warn('GOVERNMENT_PRIVATE_KEY not set - blockchain writes will fail');
if (!CONTRACT_ADDRESS) {
	logger.warn('CONTRACT_ADDRESS not set - deploy or set in .env to use existing contract');
} else {
	logger.info(`Using contract address ${CONTRACT_ADDRESS} (ensure Flutter .env matches)`);
}

// Initialize web3 (Web3 v4 accepts RPC URL directly)
const web3 = new Web3(RPC_URL);

// Load ABI
const abiPath = path.join(__dirname, '..', 'assets', 'contracts', 'TouristID.json');
if (!fs.existsSync(abiPath)) {
	throw new Error('TouristID.json ABI file not found at ' + abiPath);
}
const parsed = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
const contractABI = Array.isArray(parsed) ? parsed : (parsed.abi || parsed.ABI || parsed.contractAbi);
if (!Array.isArray(contractABI)) {
	throw new Error('Invalid ABI format in ' + abiPath);
}

let contractInstance = null;
if (CONTRACT_ADDRESS) {
	contractInstance = new web3.eth.Contract(contractABI, CONTRACT_ADDRESS);
}

// Wallet setup (government / issuer)
let govAccount = null;
try {
	if (GOVERNMENT_PRIVATE_KEY) {
		const pk = GOVERNMENT_PRIVATE_KEY.startsWith('0x') ? GOVERNMENT_PRIVATE_KEY : '0x' + GOVERNMENT_PRIVATE_KEY;
		govAccount = web3.eth.accounts.privateKeyToAccount(pk);
		// (Optional) add to wallet for future multiple signing
		web3.eth.accounts.wallet.add(govAccount);
		if (GOVERNMENT_ADDRESS && GOVERNMENT_ADDRESS.toLowerCase() !== govAccount.address.toLowerCase()) {
			logger.warn(`Configured GOVERNMENT_ADDRESS (${GOVERNMENT_ADDRESS}) does not match private key derived address (${govAccount.address})`);
		}
	}
} catch (err) {
	logger.error('Failed to initialize government account: ' + err.message);
	govAccount = null;
}

function getGovernmentAddress() {
	if (govAccount && govAccount.address) return govAccount.address;
	if (GOVERNMENT_ADDRESS) return GOVERNMENT_ADDRESS;
	return null;
}

async function getContractOwner() {
	const contract = requireContract();
	try {
		return await contract.methods.owner().call();
	} catch (e) {
		logger.warn('Failed to read contract owner(): ' + e.message);
		return null;
	}
}

/**
 * Helper to ensure contract is initialized.
 */
function requireContract() {
	if (!contractInstance) throw new Error('Contract not initialized - set CONTRACT_ADDRESS in .env');
	return contractInstance;
}

/**
 * Mint a new Tourist ID NFT.
 * @param {Object} params
 * @param {string} params.touristIdHash - hex string (32 bytes) or will be hashed with keccak256
 * @param {number|string} params.validUntil - unix timestamp (seconds)
 * @param {string} params.metadataCID - IPFS CID string
 * @param {string} params.issuerInfo - textual issuer info
 * @returns {Promise<{transactionHash:string, tokenId:string}>}
 */
async function mintTouristID({ touristIdHash, validUntil, metadataCID, issuerInfo }) {
	const contract = requireContract();
	if (!govAccount) {
		throw new Error('Government account not configured: set GOVERNMENT_PRIVATE_KEY in .env to enable minting');
	}

	// Normalize touristIdHash to bytes32
	let hash = touristIdHash;
	if (!/^0x[0-9a-fA-F]{64}$/.test(hash)) {
		// Hash the input
		hash = web3.utils.keccak256(touristIdHash);
	}

	if (!validUntil || Number(validUntil) <= Math.floor(Date.now() / 1000)) {
		throw new Error('validUntil must be a future unix timestamp (seconds)');
	}

	const chainId = CHAIN_ID ? Number(CHAIN_ID) : Number(await web3.eth.getChainId());
	const validUntilBN = typeof validUntil === 'bigint' ? validUntil : BigInt(validUntil);

	// Build tx data with primary signature (bytes32,uint256,string,string); fallback to (uint256,bytes32,string,string)
	let txData;
	try {
		txData = contract.methods.mintTouristID(hash, validUntilBN, metadataCID, issuerInfo).encodeABI();
	} catch (sigErr) {
		logger.warn('Primary mintTouristID signature failed, trying alternate order: ' + sigErr.message);
		txData = contract.methods.mintTouristID(validUntilBN, hash, metadataCID, issuerInfo).encodeABI();
	}

	// Estimate gas and fetch fee suggestions (EIP-1559). Fallbacks are provided.
	let gas;
	try {
		gas = await contract.methods
			.mintTouristID(hash, validUntilBN, metadataCID, issuerInfo)
			.estimateGas({ from: govAccount.address });
	} catch (e1) {
		try {
			gas = await contract.methods
				.mintTouristID(validUntilBN, hash, metadataCID, issuerInfo)
				.estimateGas({ from: govAccount.address });
		} catch (e2) {
			logger.warn('Gas estimate failed for both signatures, using default 500000: ' + e2.message);
			gas = 500000;
		}
	}

	let maxPriorityFeePerGas;
	let maxFeePerGas;
	try {
		maxPriorityFeePerGas = await web3.eth.getMaxPriorityFeePerGas();
		const baseFee = await web3.eth.getGasPrice(); // approximate base fee
		// Add a 20% tip over base
		maxFeePerGas = (typeof baseFee === 'bigint' ? baseFee : BigInt(baseFee)) * 12n / 10n + (typeof maxPriorityFeePerGas === 'bigint' ? maxPriorityFeePerGas : BigInt(maxPriorityFeePerGas));
	} catch (e) {
		// Fallback to legacy gasPrice if EIP-1559 not supported
		const gasPrice = await web3.eth.getGasPrice();
		maxPriorityFeePerGas = undefined;
		maxFeePerGas = undefined;
		// We will include gasPrice only in the tx object if 1559 values are undefined
	}

	// Get the current nonce
	const nonce = await web3.eth.getTransactionCount(govAccount.address, 'pending');

	const txCommon = {
		from: govAccount.address,
		to: contract.options.address,
		data: txData,
		gas,
		nonce,
		chainId
	};

	// Build transaction with 1559 fields if available
	let tx;
	if (maxFeePerGas && maxPriorityFeePerGas) {
		tx = { ...txCommon, maxFeePerGas, maxPriorityFeePerGas };
	} else {
		const gasPrice = await web3.eth.getGasPrice();
		tx = { ...txCommon, gasPrice };
	}

	const signed = await web3.eth.accounts.signTransaction(tx, govAccount.privateKey);
	const receipt = await web3.eth.sendSignedTransaction(signed.rawTransaction);

	// Try to extract tokenId from logs (Web3 v4 stores events in logs)
	let tokenId = null;
	try {
		if (receipt && Array.isArray(receipt.logs)) {
			// Find TouristIDMinted event ABI
			const eventAbi = contractABI.find(e => e.type === 'event' && e.name === 'TouristIDMinted');
			if (eventAbi) {
				const signature = web3.utils.keccak256(`${eventAbi.name}(${eventAbi.inputs.map(i => i.type).join(',')})`);
				const log = receipt.logs.find(l => (l.topics && l.topics[0] && l.topics[0].toLowerCase() === signature.toLowerCase()));
				if (log) {
					const decoded = web3.eth.abi.decodeLog(eventAbi.inputs, log.data, log.topics.slice(1));
					tokenId = decoded.tokenId ? decoded.tokenId.toString() : (decoded[0] ? decoded[0].toString() : null);
				}
			}
		}
	} catch (e) {
		logger.warn('Failed to decode TouristIDMinted from receipt logs: ' + e.message);
	}

	// Fallback: scan events from the same block to find the minted event
	if (!tokenId) {
		try {
			const events = await contractInstance.getPastEvents('TouristIDMinted', {
				fromBlock: receipt.blockNumber,
				toBlock: receipt.blockNumber
			});
			const ev = events.find(e => e && e.transactionHash && e.transactionHash.toLowerCase() === receipt.transactionHash.toLowerCase());
			if (ev && ev.returnValues && ev.returnValues.tokenId != null) {
				tokenId = ev.returnValues.tokenId.toString();
			} else if (events.length > 0 && events[0].returnValues && events[0].returnValues.tokenId != null) {
				tokenId = events[0].returnValues.tokenId.toString();
			}
		} catch (scanErr) {
			logger.warn('Event scan fallback failed: ' + scanErr.message);
		}
	}

	return { transactionHash: receipt.transactionHash, tokenId };
}

async function getTouristRecord(tokenId) {
	const contract = requireContract();
	const record = await contract.methods.getTouristRecord(tokenId).call();
	const valid = await contract.methods.isValid(tokenId).call();
	return {
		tokenId: tokenId.toString(),
		touristIdHash: record.touristIdHash,
		validUntil: Number(record.validUntil),
		metadataCID: record.metadataCID,
		issuerInfo: record.issuerInfo,
		isValid: valid
	};
}

async function isValid(tokenId) {
	const contract = requireContract();
	return contract.methods.isValid(tokenId).call();
}

async function getGovernmentBalance() {
	if (!govAccount && !GOVERNMENT_ADDRESS) throw new Error('Government address not configured');
	const address = govAccount ? govAccount.address : GOVERNMENT_ADDRESS;
	const balanceWei = await web3.eth.getBalance(address);
	return web3.utils.fromWei(balanceWei, 'ether');
}

/**
 * Fetch active Tourist IDs through events (on-chain enumeration not provided by contract).
 * NOTE: This scans events which can be expensive for large histories; for production consider indexing.
 */
async function getAllActiveTouristIDs(page = 1, limit = 20) {
	const contract = requireContract();
	page = Number(page) || 1;
	limit = Number(limit) || 20;

	// Fetch all mint events
	const events = await contract.getPastEvents('TouristIDMinted', { fromBlock: 0, toBlock: 'latest' });
	const tokenIds = events.map(e => e.returnValues.tokenId);

	// Fetch validity in parallel (throttle if necessary)
	const results = [];
	for (const tokenId of tokenIds) {
		try {
			const record = await getTouristRecord(tokenId);
			if (record.isValid) results.push(record);
		} catch (e) {
			logger.warn(`Failed to retrieve record for tokenId ${tokenId}: ${e.message}`);
		}
	}

	// Pagination
	const total = results.length;
	const start = (page - 1) * limit;
	const paginated = results.slice(start, start + limit);
	return { page, limit, total, data: paginated };
}

module.exports = {
	web3,
	contract: () => requireContract(),
	getGovernmentAddress,
	getContractOwner,
	mintTouristID,
	getTouristRecord,
	isValid,
	getGovernmentBalance,
	getAllActiveTouristIDs
};
