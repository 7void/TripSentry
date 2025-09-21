import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/tourist_record.dart';

// web3dart imported with alias `web3` for clarity when interacting with Ethereum types.

class BlockchainService {
  // Loaded from environment (.env) to stay in sync with backend
  late String _rpcUrl; // reassignable to avoid late-final reinit errors
  late String _contractAddress;
  late int _chainId;
  bool _initializing = false; // prevents concurrent initialization of late finals

  late Web3Client _client;
  late DeployedContract _contract; // Assigned only if ABI loads successfully
  bool _contractLoaded = false; // Tracks whether contract + functions were set

  // Existing functions
  late ContractFunction _getTouristRecord;
  late ContractFunction _isValidTouristID;
  late ContractFunction _balanceOf;
  late ContractFunction _ownerOf;
  late ContractFunction _contractOwner; // Ownable.owner()
  // Note: Advanced functions not present in current ABI are intentionally not declared
  // Removed setCentralWallet; contract does not expose this in current ABI

  // Contract state variables
  // No central wallet in current contract; removed

  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  Future<void> initialize() async {
    if (_contractLoaded) return; // already good
    if (_initializing) {
      // Another caller is already initializing; wait until done
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return; // After wait, either loaded or will retry on next call
    }

    _initializing = true;
    try {
      // Only set late finals once
      _rpcUrl = dotenv.env['RPC_URL']?.trim() ?? '';
      _contractAddress = dotenv.env['CONTRACT_ADDRESS']?.trim() ?? '';
      final chainIdStr = dotenv.env['CHAIN_ID']?.trim();
      _chainId = int.tryParse(chainIdStr ?? '') ?? 11155111; // default to Sepolia

      if (_rpcUrl.isEmpty) {
        print('[BlockchainService] ERROR: RPC_URL missing in .env');
      }
      if (_contractAddress.isEmpty) {
        print('[BlockchainService] WARNING: CONTRACT_ADDRESS missing in .env');
      }
      print('[BlockchainService] Using RPC=$_rpcUrl contract=$_contractAddress chainId=$_chainId');
      _client = Web3Client(_rpcUrl, Client());
      await _loadContract();
    } finally {
      _initializing = false;
    }
  }

  Future<bool> ensureInitialized() async {
    if (!_contractLoaded) {
      await initialize();
    }
    return _contractLoaded;
  }

  Future<void> _loadContract() async {
    try {
    final abiString =
      await rootBundle.loadString('assets/contracts/TouristID.json');

    // Support both raw ABI array OR full artifact (with an 'abi' field)
    final decoded = jsonDecode(abiString);
    final abi = decoded is List
      ? decoded
      : (decoded is Map && decoded['abi'] is List
        ? decoded['abi']
        : throw Exception('ABI format not recognized in TouristID.json')) as List<dynamic>;

      _contract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(abi), 'TouristID'),
        EthereumAddress.fromHex(_contractAddress),
      );

  // Functions present in current contract
  _getTouristRecord = _contract.function('getTouristRecord');
  _isValidTouristID = _contract.function('isValid');
  _balanceOf = _contract.function('balanceOf');
  _ownerOf = _contract.function('ownerOf');
      // Ownable owner function for resolving issuer (optional in some ABI bundles)
      try {
        _contractOwner = _contract.function('owner');
      } catch (_) {
        // owner() may be missing in ABI file; fallback will be disabled
        print('[BlockchainService] owner() not found in ABI');
      }
  // Skip non-existent advanced functions in this version
  // No setCentralWallet or centralWallet in current contract version

      _contractLoaded = true;
      print('Enhanced contract loaded successfully');
    } catch (e) {
      print('Error loading contract: $e');
      // Don't throw exception, just log the error and continue
      print(
          'Contract loading failed, but continuing without blockchain functionality');
      _contractLoaded = false;
    }
  }


  // Generate hash for tourist ID (Aadhaar or Passport)
  String generateTouristIdHash(String identityDocument) {
    final bytes = utf8.encode(identityDocument);
    final digest = sha256.convert(bytes);
    return '0x${digest.toString()}';
  }

  // Updated mint function with issuerInfo parameter
  Future<String> mintTouristID({
    required String touristAddress,
    required String touristIdHash,
    required DateTime validUntil,
    required String metadataCID,
    required String ownerPrivateKey,
    String issuerInfo = 'Government Tourism Authority', // Default issuer info
  }) async {
    // Client-side minting is disabled for this contract; use backend service
    throw UnsupportedError('Client-side minting is disabled. Use BackendService.createTouristID()');
  }

  // Get tourist record by token ID
  Future<TouristRecord?> getTouristRecord(int tokenId) async {
    try {
      if (!await ensureInitialized()) {
        print('Contract not initialized – getTouristRecord aborted');
        return null;
      }
      final result = await _client.call(
        contract: _contract,
        function: _getTouristRecord,
        params: [BigInt.from(tokenId)],
      );

      if (result.isNotEmpty) {
        return TouristRecord.fromList(result[0]);
      }
      return null;
    } catch (e) {
      print('Error getting tourist record: $e');
      return null;
    }
  }

  // Get tourist address associated with a token ID
  Future<String?> getTouristOf(int tokenId) async {
    // Not supported by current contract
    return null;
  }

  // Get token ID associated with a tourist address
  Future<int?> getTokenOfTourist(String touristAddress) async {
    // Not supported by current contract
    return null;
  }

  // Get all token IDs in the system
  Future<List<int>> getAllTokenIds() async {
    // Not supported by current contract
    return [];
  }

  // Get all active tourist IDs with their associated addresses
  Future<Map<int, String>> getAllActiveTouristIDs() async {
    // Not supported by current contract
    return {};
  }

  // No central wallet function available in this contract variant

  // No setCentralWallet in current contract; method removed

  // Force delete Tourist ID (only owner)
  Future<String> forceDeleteTouristID({
    required int tokenId,
    required String ownerPrivateKey,
  }) async {
    throw UnsupportedError('forceDeleteTouristID is not supported by current contract');
  }

  // Batch delete expired Tourist IDs
  Future<String> batchDeleteExpired({
    required List<int> tokenIds,
    required String privateKey,
  }) async {
    throw UnsupportedError('batchDeleteExpired is not supported by current contract');
  }

  // Get token ID by tourist hash
  Future<int?> getTokenIdByTouristHash(String touristIdHash) async {
    // Not supported by current contract
    return null;
  }

  // Check if Tourist ID is valid
  Future<bool> isValidTouristID(int tokenId) async {
    try {
      if (!await ensureInitialized()) {
        print('Contract not initialized – isValidTouristID aborted');
        return false;
      }
      final result = await _client.call(
        contract: _contract,
        function: _isValidTouristID,
        params: [BigInt.from(tokenId)],
      );

      return result.isNotEmpty ? result[0] as bool : false;
    } catch (e) {
      print('Error checking validity: $e');
      return false;
    }
  }

  // Check if Tourist ID is expired
  Future<bool> isExpired(int tokenId) async {
    // Compute expiration from record.validUntil
    try {
      if (!await ensureInitialized()) {
        print('Contract not initialized – isExpired aborted');
        return true;
      }
      final result = await _client.call(
        contract: _contract,
        function: _getTouristRecord,
        params: [BigInt.from(tokenId)],
      );
      if (result.isNotEmpty) {
        final data = result[0] as List<dynamic>;
        final validUntilSec = (data[1] as BigInt).toInt();
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return nowSec >= validUntilSec;
      }
      return true;
    } catch (e) {
      print('Error computing expiration from record: $e');
      return true;
    }
  }

  // Update metadata CID
  Future<String> updateMetadata({
    required int tokenId,
    required String newMetadataCID,
    required String touristPrivateKey,
  }) async {
    throw UnsupportedError('updateMetadata is not supported by current contract');
  }

  // Delete expired Tourist ID
  Future<String> deleteExpiredTouristID({
    required int tokenId,
    required String privateKey,
  }) async {
    throw UnsupportedError('deleteExpiredTouristID is not supported by current contract');
  }

  // Get total active IDs
  Future<int> getTotalActiveIDs() async {
    // Not supported by current contract
    return 0;
  }

  // Get balance of address
  Future<int> getBalanceOf(String address) async {
    try {
      if (!await ensureInitialized()) {
        print('Contract not initialized – getBalanceOf aborted');
        return 0;
      }
      final result = await _client.call(
        contract: _contract,
        function: _balanceOf,
        params: [EthereumAddress.fromHex(address)],
      );

      return result.isNotEmpty ? (result[0] as BigInt).toInt() : 0;
    } catch (e) {
      print('Error getting balance: $e');
      return 0;
    }
  }

  // Get owner of token (will always return central wallet)
  Future<String?> getOwnerOf(int tokenId) async {
    try {
      if (!await ensureInitialized()) {
        print('Contract not initialized – getOwnerOf aborted');
        return null;
      }
      final result = await _client.call(
        contract: _contract,
        function: _ownerOf,
        params: [BigInt.from(tokenId)],
      );

      return result.isNotEmpty ? (result[0] as EthereumAddress).hex : null;
    } catch (e) {
      print('Error getting owner: $e');
      return null;
    }
  }

  // Get contract owner (issuer/government wallet)
  Future<String?> getContractOwner() async {
    try {
      if (!await ensureInitialized()) {
        print('Contract not initialized – getContractOwner aborted');
        return null;
      }
      final result = await _client.call(
        contract: _contract,
        function: _contractOwner,
        params: [],
      );
      return result.isNotEmpty ? (result[0] as EthereumAddress).hex : null;
    } catch (e) {
      print('Error getting contract owner: $e');
      return null;
    }
  }

  // Helper method to get comprehensive tourist info
  Future<Map<String, dynamic>?> getCompleteTouristInfo(int tokenId) async {
    try {
      if (!await ensureInitialized()) {
        print('Contract not initialized – getCompleteTouristInfo aborted');
        return null;
      }
      final record = await getTouristRecord(tokenId);
      final tourist = await getTouristOf(tokenId);
      final owner = await getOwnerOf(tokenId);
      final isValid = await isValidTouristID(tokenId);
      final isExpiredStatus = await isExpired(tokenId);

      return {
        'tokenId': tokenId,
        'record': record,
        'touristAddress': tourist,
        'ownerAddress': owner, // Central wallet
        'isValid': isValid,
        'isExpired': isExpiredStatus,
      };
    } catch (e) {
      print('Error getting complete tourist info: $e');
      return null;
    }
  }

  // Get gas price
  Future<EtherAmount> getGasPrice() async {
    try {
      return await _client.getGasPrice();
    } catch (e) {
      print('Error getting gas price: $e');
      return EtherAmount.inWei(
          BigInt.from(20000000000)); // 20 Gwei default
    }
  }

  // Get ETH balance
  Future<EtherAmount> getEthBalance(String address) async {
    try {
      return await _client.getBalance(EthereumAddress.fromHex(address));
    } catch (e) {
      print('Error getting ETH balance: $e');
      return EtherAmount.zero();
    }
  }

  // Wait for transaction confirmation
  Future<TransactionReceipt?> waitForTransactionReceipt(
      String txHash) async {
    try {
      TransactionReceipt? receipt;
      int attempts = 0;
      const maxAttempts =
          30; // 30 attempts with 2-second delay = 1 minute timeout

      while (receipt == null && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 2));
        receipt = await _client.getTransactionReceipt(txHash);
        attempts++;
      }

      return receipt;
    } catch (e) {
      print('Error waiting for transaction receipt: $e');
      return null;
    }
  }

  void dispose() {
    _client.dispose();
  }
}
