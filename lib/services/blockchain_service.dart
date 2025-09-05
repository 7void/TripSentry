import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import '../models/tourist_record.dart';

class BlockchainService {
  static const String _rpcUrl = 'https://eth-sepolia.g.alchemy.com/v2/-RGNirb5XtTS_mKCFbeMY'; // Replace with your Sepolia RPC URL
  static const String _contractAddress = '0x92d4b424a2dd5f513982929b3353be196b043879'; // Replace with deployed contract address
  static const int _chainId = 11155111; // Ethereum Sepolia testnet
  
  late Web3Client _client;
  late DeployedContract _contract;
  late ContractFunction _mintTouristID;
  late ContractFunction _getTouristRecord;
  late ContractFunction _updateMetadata;
  late ContractFunction _isValidTouristID;
  late ContractFunction _isExpired;
  late ContractFunction _getTokenIdByTouristHash;
  late ContractFunction _deleteExpiredTouristID;
  late ContractFunction _totalActiveIDs;
  late ContractFunction _balanceOf;
  late ContractFunction _ownerOf;

  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  Future<void> initialize() async {
    _client = Web3Client(_rpcUrl, Client());
    await _loadContract();
  }

  Future<void> _loadContract() async {
    try {
      final abiString = await rootBundle.loadString('assets/contracts/TouristID.json');
      final abi = jsonDecode(abiString) as List<dynamic>;
      
      _contract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(abi), 'TouristID'),
        EthereumAddress.fromHex(_contractAddress),
      );

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
      
      print('Contract loaded successfully');
    } catch (e) {
      print('Error loading contract: $e');
      throw Exception('Failed to load contract: $e');
    }
  }

  // Generate a new wallet
  WalletInfo generateWallet() {
    final random = Random.secure();
    final credentials = EthPrivateKey.createRandom(random);
    
    return WalletInfo(
      address: credentials.address.hex,
      privateKey: credentials.privateKeyInt.toRadixString(16),
      publicKey: credentials.publicKey.getEncoded(false),
    );
  }

  // Create credentials from private key
  EthPrivateKey _getCredentials(String privateKey) {
    return EthPrivateKey.fromHex(privateKey);
  }

  // Generate hash for tourist ID (Aadhaar or Passport)
  String generateTouristIdHash(String identityDocument) {
    final bytes = utf8.encode(identityDocument);
    final digest = sha256.convert(bytes);
    return '0x${digest.toString()}';
  }

  // Mint a new Tourist ID NFT
  Future<String> mintTouristID({
    required String touristAddress,
    required String touristIdHash,
    required DateTime validUntil,
    required String metadataCID,
    required String ownerPrivateKey,
  }) async {
    try {
      final credentials = _getCredentials(ownerPrivateKey);
      
      final transaction = Transaction.callContract(
        contract: _contract,
        function: _mintTouristID,
        parameters: [
          EthereumAddress.fromHex(touristAddress),
          Uint8List.fromList(hex.decode(touristIdHash.substring(2))), // Remove 0x prefix
          BigInt.from(validUntil.millisecondsSinceEpoch ~/ 1000), // Convert to seconds
          metadataCID,
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

  // Get token ID by tourist hash
  Future<int?> getTokenIdByTouristHash(String touristIdHash) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTokenIdByTouristHash,
        params: [Uint8List.fromList(hex.decode(touristIdHash.substring(2)))],
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
      
      final transaction = Transaction.callContract(
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
      
      final transaction = Transaction.callContract(
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
        params: [EthereumAddress.fromHex(address)],
      );

      return result.isNotEmpty ? (result[0] as BigInt).toInt() : 0;
    } catch (e) {
      print('Error getting balance: $e');
      return 0;
    }
  }

  // Get owner of token
  Future<String?> getOwnerOf(int tokenId) async {
    try {
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

  // Get gas price
  Future<EtherAmount> getGasPrice() async {
    try {
      return await _client.getGasPrice();
    } catch (e) {
      print('Error getting gas price: $e');
      return EtherAmount.inWei(BigInt.from(20000000000)); // 20 Gwei default
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
  Future<TransactionReceipt?> waitForTransactionReceipt(String txHash) async {
    try {
      TransactionReceipt? receipt;
      int attempts = 0;
      const maxAttempts = 30; // 30 attempts with 2-second delay = 1 minute timeout
      
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