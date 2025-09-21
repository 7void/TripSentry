import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:convert/convert.dart' as convert;
import '../models/tourist_record.dart';

// web3dart imported with alias `web3` for clarity when interacting with Ethereum types.

class BlockchainService {
  static const String _rpcUrl =
      'https://eth-sepolia.g.alchemy.com/v2/-RGNirb5XtTS_mKCFbeMY';
  static const String _contractAddress =
      '0x8d95bbd64547caf83bfa6af67b522ec6d1450a85';
  static const int _chainId = 11155111;

  late web3.Web3Client _client;
  late web3.DeployedContract _contract;

  // Existing functions
  late web3.ContractFunction _mintTouristID;
  late web3.ContractFunction _getTouristRecord;
  late web3.ContractFunction _updateMetadata;
  late web3.ContractFunction _isValidTouristID;
  late web3.ContractFunction _isExpired;
  late web3.ContractFunction _getTokenIdByTouristHash;
  late web3.ContractFunction _deleteExpiredTouristID;
  late web3.ContractFunction _totalActiveIDs;
  late web3.ContractFunction _balanceOf;
  late web3.ContractFunction _ownerOf;
  late web3.ContractFunction _forceDeleteTouristID;
  late web3.ContractFunction _batchDeleteExpired;

  // New functions for enhanced contract
  late web3.ContractFunction _getTouristOf;
  late web3.ContractFunction _getTokenOfTourist;
  late web3.ContractFunction _getAllTokenIds;
  late web3.ContractFunction _getAllActiveTouristIDs;
  late web3.ContractFunction _setCentralWallet;

  // Contract state variables
  late web3.ContractFunction _centralWallet;

  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  Future<void> initialize() async {
    _client = web3.Web3Client(_rpcUrl, Client());
    await _loadContract();
  }

  Future<void> _loadContract() async {
    try {
      final abiString =
          await rootBundle.loadString('assets/contracts/TouristID.json');
      final abi = jsonDecode(abiString) as List<dynamic>;

      _contract = web3.DeployedContract(
        web3.ContractAbi.fromJson(jsonEncode(abi), 'TouristID'),
        web3.EthereumAddress.fromHex(_contractAddress),
      );

      // Existing functions
      _mintTouristID = _contract.function('mintTouristID');
      _getTouristRecord = _contract.function('getTouristRecord');
      _updateMetadata = _contract.function('updateMetadata');
      _isValidTouristID = _contract.function('isValidTouristID');
      _isExpired = _contract.function('isExpired');
      _getTokenIdByTouristHash = _contract.function('getTokenIdByTouristHash');
      _deleteExpiredTouristID = _contract.function('deleteExpiredTouristID');
      _totalActiveIDs = _contract.function('totalActiveIDs');
      _balanceOf = _contract.function('balanceOf');
      _ownerOf = _contract.function('ownerOf');
      _forceDeleteTouristID = _contract.function('forceDeleteTouristID');
      _batchDeleteExpired = _contract.function('batchDeleteExpired');

      // New functions for enhanced contract
      _getTouristOf = _contract.function('getTouristOf');
      _getTokenOfTourist = _contract.function('getTokenOfTourist');
      _getAllTokenIds = _contract.function('getAllTokenIds');
      _getAllActiveTouristIDs = _contract.function('getAllActiveTouristIDs');
      _setCentralWallet = _contract.function('setCentralWallet');

      // State variables
      _centralWallet = _contract.function('centralWallet');

      print('Enhanced contract loaded successfully');
    } catch (e) {
      print('Error loading contract: $e');
      // Don't throw exception, just log the error and continue
      print(
          'Contract loading failed, but continuing without blockchain functionality');
    }
  }

  // Create credentials from private key
  web3.EthPrivateKey _getCredentials(String privateKey) {
    return web3.EthPrivateKey.fromHex(privateKey);
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
    try {
      final credentials = _getCredentials(ownerPrivateKey);

      final transaction = web3.Transaction.callContract(
        contract: _contract,
        function: _mintTouristID,
        parameters: [
          web3.EthereumAddress.fromHex(touristAddress),
          Uint8List.fromList(convert.hex.decode(touristIdHash.substring(2))),
          BigInt.from(validUntil.millisecondsSinceEpoch ~/ 1000),
          metadataCID,
          issuerInfo, // New parameter
        ],
        maxGas: 500000,
      );

      final result = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: _chainId,
      );

      return result;
    } catch (e) {
      print('Error minting Tourist ID: $e');
      throw Exception('Failed to mint Tourist ID: $e');
    }
  }

  // Get tourist record by token ID
  Future<TouristRecord?> getTouristRecord(int tokenId) async {
    try {
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
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTouristOf,
        params: [BigInt.from(tokenId)],
      );

      return result.isNotEmpty ? (result[0] as web3.EthereumAddress).hex : null;
    } catch (e) {
      print('Error getting tourist of token: $e');
      return null;
    }
  }

  // Get token ID associated with a tourist address
  Future<int?> getTokenOfTourist(String touristAddress) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTokenOfTourist,
        params: [web3.EthereumAddress.fromHex(touristAddress)],
      );

      return result.isNotEmpty ? (result[0] as BigInt).toInt() : null;
    } catch (e) {
      print('Error getting token of tourist: $e');
      return null;
    }
  }

  // Get all token IDs in the system
  Future<List<int>> getAllTokenIds() async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getAllTokenIds,
        params: [],
      );

      if (result.isNotEmpty) {
        final tokenIds = result[0] as List<dynamic>;
        return tokenIds.map((id) => (id as BigInt).toInt()).toList();
      }
      return [];
    } catch (e) {
      print('Error getting all token IDs: $e');
      return [];
    }
  }

  // Get all active tourist IDs with their associated addresses
  Future<Map<int, String>> getAllActiveTouristIDs() async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getAllActiveTouristIDs,
        params: [],
      );

      if (result.isNotEmpty && result.length >= 2) {
        final tokenIds = result[0] as List<dynamic>;
        final tourists = result[1] as List<dynamic>;

        Map<int, String> activeIDs = {};
        for (int i = 0; i < tokenIds.length; i++) {
          final tokenId = (tokenIds[i] as BigInt).toInt();
          final touristAddress = (tourists[i] as web3.EthereumAddress).hex;
          activeIDs[tokenId] = touristAddress;
        }
        return activeIDs;
      }
      return {};
    } catch (e) {
      print('Error getting all active tourist IDs: $e');
      return {};
    }
  }

  // Get central wallet address
  Future<String?> getCentralWallet() async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _centralWallet,
        params: [],
      );

      return result.isNotEmpty ? (result[0] as web3.EthereumAddress).hex : null;
    } catch (e) {
      print('Error getting central wallet: $e');
      return null;
    }
  }

  // Set new central wallet (only contract owner)
  Future<String> setCentralWallet({
    required String newCentralWallet,
    required String ownerPrivateKey,
  }) async {
    try {
      final credentials = _getCredentials(ownerPrivateKey);

      final transaction = web3.Transaction.callContract(
        contract: _contract,
        function: _setCentralWallet,
        parameters: [web3.EthereumAddress.fromHex(newCentralWallet)],
        maxGas: 300000,
      );

      final result = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: _chainId,
      );

      return result;
    } catch (e) {
      print('Error setting central wallet: $e');
      throw Exception('Failed to set central wallet: $e');
    }
  }

  // Force delete Tourist ID (only owner)
  Future<String> forceDeleteTouristID({
    required int tokenId,
    required String ownerPrivateKey,
  }) async {
    try {
      final credentials = _getCredentials(ownerPrivateKey);

      final transaction = web3.Transaction.callContract(
        contract: _contract,
        function: _forceDeleteTouristID,
        parameters: [BigInt.from(tokenId)],
        maxGas: 300000,
      );

      final result = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: _chainId,
      );

      return result;
    } catch (e) {
      print('Error force deleting Tourist ID: $e');
      throw Exception('Failed to force delete Tourist ID: $e');
    }
  }

  // Batch delete expired Tourist IDs
  Future<String> batchDeleteExpired({
    required List<int> tokenIds,
    required String privateKey,
  }) async {
    try {
      final credentials = _getCredentials(privateKey);

      final transaction = web3.Transaction.callContract(
        contract: _contract,
        function: _batchDeleteExpired,
        parameters: [tokenIds.map((id) => BigInt.from(id)).toList()],
        maxGas: 1000000, // Higher gas limit for batch operations
      );

      final result = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: _chainId,
      );

      return result;
    } catch (e) {
      print('Error batch deleting expired IDs: $e');
      throw Exception('Failed to batch delete expired IDs: $e');
    }
  }

  // Get token ID by tourist hash
  Future<int?> getTokenIdByTouristHash(String touristIdHash) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTokenIdByTouristHash,
        params: [
          Uint8List.fromList(convert.hex.decode(touristIdHash.substring(2)))
        ],
      );

      if (result.isNotEmpty) {
        return (result[0] as BigInt).toInt();
      }
      return null;
    } catch (e) {
      print('Error getting token ID: $e');
      return null;
    }
  }

  // Check if Tourist ID is valid
  Future<bool> isValidTouristID(int tokenId) async {
    try {
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
    try {
      final result = await _client.call(
        contract: _contract,
        function: _isExpired,
        params: [BigInt.from(tokenId)],
      );

      return result.isNotEmpty ? result[0] as bool : false;
    } catch (e) {
      print('Error checking expiration: $e');
      return false;
    }
  }

  // Update metadata CID
  Future<String> updateMetadata({
    required int tokenId,
    required String newMetadataCID,
    required String touristPrivateKey,
  }) async {
    try {
      final credentials = _getCredentials(touristPrivateKey);

      final transaction = web3.Transaction.callContract(
        contract: _contract,
        function: _updateMetadata,
        parameters: [
          BigInt.from(tokenId),
          newMetadataCID,
        ],
        maxGas: 200000,
      );

      final result = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: _chainId,
      );

      return result;
    } catch (e) {
      print('Error updating metadata: $e');
      throw Exception('Failed to update metadata: $e');
    }
  }

  // Delete expired Tourist ID
  Future<String> deleteExpiredTouristID({
    required int tokenId,
    required String privateKey,
  }) async {
    try {
      final credentials = _getCredentials(privateKey);

      final transaction = web3.Transaction.callContract(
        contract: _contract,
        function: _deleteExpiredTouristID,
        parameters: [BigInt.from(tokenId)],
        maxGas: 300000,
      );

      final result = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: _chainId,
      );

      return result;
    } catch (e) {
      print('Error deleting expired ID: $e');
      throw Exception('Failed to delete expired ID: $e');
    }
  }

  // Get total active IDs
  Future<int> getTotalActiveIDs() async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _totalActiveIDs,
        params: [],
      );

      return result.isNotEmpty ? (result[0] as BigInt).toInt() : 0;
    } catch (e) {
      print('Error getting total active IDs: $e');
      return 0;
    }
  }

  // Get balance of address
  Future<int> getBalanceOf(String address) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _balanceOf,
        params: [web3.EthereumAddress.fromHex(address)],
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
      final result = await _client.call(
        contract: _contract,
        function: _ownerOf,
        params: [BigInt.from(tokenId)],
      );

      return result.isNotEmpty ? (result[0] as web3.EthereumAddress).hex : null;
    } catch (e) {
      print('Error getting owner: $e');
      return null;
    }
  }

  // Helper method to get comprehensive tourist info
  Future<Map<String, dynamic>?> getCompleteTouristInfo(int tokenId) async {
    try {
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
  Future<web3.EtherAmount> getGasPrice() async {
    try {
      return await _client.getGasPrice();
    } catch (e) {
      print('Error getting gas price: $e');
      return web3.EtherAmount.inWei(
          BigInt.from(20000000000)); // 20 Gwei default
    }
  }

  // Get ETH balance
  Future<web3.EtherAmount> getEthBalance(String address) async {
    try {
      return await _client.getBalance(web3.EthereumAddress.fromHex(address));
    } catch (e) {
      print('Error getting ETH balance: $e');
      return web3.EtherAmount.zero();
    }
  }

  // Wait for transaction confirmation
  Future<web3.TransactionReceipt?> waitForTransactionReceipt(
      String txHash) async {
    try {
      web3.TransactionReceipt? receipt;
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
