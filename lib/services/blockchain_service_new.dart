import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:convert/convert.dart' as convert;
import '../models/tourist_record.dart';

class BlockchainServiceNew {
  static const String _rpcUrl =
      'https://eth-sepolia.g.alchemy.com/v2/-RGNirb5XtTS_mKCFbeMY';
  static const String _contractAddress =
      '0x8d95bbd64547caf83bfa6af67b522ec6d1450a85';
  static const int _chainId = 11155111;

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
  late ContractFunction _forceDeleteTouristID;
  late ContractFunction _batchDeleteExpired;

  late ContractFunction _getTouristOf;
  late ContractFunction _getTokenOfTourist;
  late ContractFunction _getAllTokenIds;
  late ContractFunction _getAllActiveTouristIDs;
  late ContractFunction _setCentralWallet;
  late ContractFunction _centralWallet;

  static final BlockchainServiceNew _instance =
      BlockchainServiceNew._internal();
  factory BlockchainServiceNew() => _instance;
  BlockchainServiceNew._internal();

  Future<void> initialize() async {
    _client = Web3Client(_rpcUrl, Client());
    await _loadContract();
  }

  Future<void> _loadContract() async {
    try {
      final abiString =
          await rootBundle.loadString('assets/contracts/TouristID.json');
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
      _forceDeleteTouristID = _contract.function('forceDeleteTouristID');
      _batchDeleteExpired = _contract.function('batchDeleteExpired');

      _getTouristOf = _contract.function('getTouristOf');
      _getTokenOfTourist = _contract.function('getTokenOfTourist');
      _getAllTokenIds = _contract.function('getAllTokenIds');
      _getAllActiveTouristIDs = _contract.function('getAllActiveTouristIDs');
      _setCentralWallet = _contract.function('setCentralWallet');
      _centralWallet = _contract.function('centralWallet');

      print('Contract loaded successfully (new service)');
    } catch (e) {
      print('Error loading contract (new service): $e');
    }
  }

  EthPrivateKey _getCredentials(String privateKey) =>
      EthPrivateKey.fromHex(privateKey);

  String generateTouristIdHash(String identityDocument) {
    final bytes = utf8.encode(identityDocument);
    final digest = sha256.convert(bytes);
    return '0x${digest.toString()}';
  }

  Future<String> mintTouristID({
    required String touristAddress,
    required String touristIdHash,
    required DateTime validUntil,
    required String metadataCID,
    required String ownerPrivateKey,
    String issuerInfo = 'Government Tourism Authority',
  }) async {
    try {
      final credentials = _getCredentials(ownerPrivateKey);
      final tx = Transaction.callContract(
        contract: _contract,
        function: _mintTouristID,
        parameters: [
          EthereumAddress.fromHex(touristAddress),
          Uint8List.fromList(convert.hex.decode(touristIdHash.substring(2))),
          BigInt.from(validUntil.millisecondsSinceEpoch ~/ 1000),
          metadataCID,
          issuerInfo,
        ],
        maxGas: 500000,
      );
      return _client.sendTransaction(credentials, tx, chainId: _chainId);
    } catch (e) {
      rethrow;
    }
  }

  Future<TouristRecord?> getTouristRecord(int tokenId) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTouristRecord,
        params: [BigInt.from(tokenId)],
      );
      if (result.isNotEmpty) return TouristRecord.fromList(result[0]);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getTouristOf(int tokenId) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTouristOf,
        params: [BigInt.from(tokenId)],
      );
      return result.isNotEmpty ? (result[0] as EthereumAddress).hex : null;
    } catch (_) {
      return null;
    }
  }

  Future<int?> getTokenOfTourist(String touristAddress) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTokenOfTourist,
        params: [EthereumAddress.fromHex(touristAddress)],
      );
      return result.isNotEmpty ? (result[0] as BigInt).toInt() : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> getAllTokenIds() async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getAllTokenIds,
        params: [],
      );
      if (result.isEmpty) return [];
      final tokenIds = result[0] as List<dynamic>;
      return tokenIds.map((e) => (e as BigInt).toInt()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<int, String>> getAllActiveTouristIDs() async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getAllActiveTouristIDs,
        params: [],
      );
      if (result.length < 2) return {};
      final tokenIds = result[0] as List<dynamic>;
      final tourists = result[1] as List<dynamic>;
      final map = <int, String>{};
      for (var i = 0; i < tokenIds.length; i++) {
        map[(tokenIds[i] as BigInt).toInt()] =
            (tourists[i] as EthereumAddress).hex;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<String?> getCentralWallet() async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _centralWallet,
        params: [],
      );
      return result.isNotEmpty ? (result[0] as EthereumAddress).hex : null;
    } catch (_) {
      return null;
    }
  }

  Future<String> setCentralWallet({
    required String newCentralWallet,
    required String ownerPrivateKey,
  }) async {
    final credentials = _getCredentials(ownerPrivateKey);
    final tx = Transaction.callContract(
      contract: _contract,
      function: _setCentralWallet,
      parameters: [EthereumAddress.fromHex(newCentralWallet)],
      maxGas: 300000,
    );
    return _client.sendTransaction(credentials, tx, chainId: _chainId);
  }

  Future<String> forceDeleteTouristID({
    required int tokenId,
    required String ownerPrivateKey,
  }) async {
    final credentials = _getCredentials(ownerPrivateKey);
    final tx = Transaction.callContract(
      contract: _contract,
      function: _forceDeleteTouristID,
      parameters: [BigInt.from(tokenId)],
      maxGas: 300000,
    );
    return _client.sendTransaction(credentials, tx, chainId: _chainId);
  }

  Future<String> batchDeleteExpired({
    required List<int> tokenIds,
    required String privateKey,
  }) async {
    final credentials = _getCredentials(privateKey);
    final tx = Transaction.callContract(
      contract: _contract,
      function: _batchDeleteExpired,
      parameters: [tokenIds.map((e) => BigInt.from(e)).toList()],
      maxGas: 1000000,
    );
    return _client.sendTransaction(credentials, tx, chainId: _chainId);
  }

  Future<int?> getTokenIdByTouristHash(String touristIdHash) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTokenIdByTouristHash,
        params: [
          Uint8List.fromList(convert.hex.decode(touristIdHash.substring(2)))
        ],
      );
      if (result.isEmpty) return null;
      return (result[0] as BigInt).toInt();
    } catch (_) {
      return null;
    }
  }

  Future<bool> isValidTouristID(int tokenId) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _isValidTouristID,
        params: [BigInt.from(tokenId)],
      );
      return result.isNotEmpty && result[0] as bool;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isExpired(int tokenId) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _isExpired,
        params: [BigInt.from(tokenId)],
      );
      return result.isNotEmpty && result[0] as bool;
    } catch (_) {
      return false;
    }
  }

  Future<String> updateMetadata({
    required int tokenId,
    required String newMetadataCID,
    required String touristPrivateKey,
  }) async {
    final credentials = _getCredentials(touristPrivateKey);
    final tx = Transaction.callContract(
      contract: _contract,
      function: _updateMetadata,
      parameters: [BigInt.from(tokenId), newMetadataCID],
      maxGas: 200000,
    );
    return _client.sendTransaction(credentials, tx, chainId: _chainId);
  }

  Future<String> deleteExpiredTouristID({
    required int tokenId,
    required String privateKey,
  }) async {
    final credentials = _getCredentials(privateKey);
    final tx = Transaction.callContract(
      contract: _contract,
      function: _deleteExpiredTouristID,
      parameters: [BigInt.from(tokenId)],
      maxGas: 300000,
    );
    return _client.sendTransaction(credentials, tx, chainId: _chainId);
  }

  Future<int> getTotalActiveIDs() async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _totalActiveIDs,
        params: [],
      );
      return result.isNotEmpty ? (result[0] as BigInt).toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getBalanceOf(String address) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _balanceOf,
        params: [EthereumAddress.fromHex(address)],
      );
      return result.isNotEmpty ? (result[0] as BigInt).toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<String?> getOwnerOf(int tokenId) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _ownerOf,
        params: [BigInt.from(tokenId)],
      );
      return result.isNotEmpty ? (result[0] as EthereumAddress).hex : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCompleteTouristInfo(int tokenId) async {
    try {
      final record = await getTouristRecord(tokenId);
      final tourist = await getTouristOf(tokenId);
      final owner = await getOwnerOf(tokenId);
      final valid = await isValidTouristID(tokenId);
      final expired = await isExpired(tokenId);
      return {
        'tokenId': tokenId,
        'record': record,
        'touristAddress': tourist,
        'ownerAddress': owner,
        'isValid': valid,
        'isExpired': expired,
      };
    } catch (_) {
      return null;
    }
  }

  Future<EtherAmount> getGasPrice() async {
    try {
      return _client.getGasPrice();
    } catch (_) {
      return EtherAmount.inWei(BigInt.from(20000000000));
    }
  }

  Future<EtherAmount> getEthBalance(String address) async {
    try {
      return _client.getBalance(EthereumAddress.fromHex(address));
    } catch (_) {
      return EtherAmount.zero();
    }
  }

  Future<TransactionReceipt?> waitForTransactionReceipt(String txHash) async {
    try {
      TransactionReceipt? receipt;
      int attempts = 0;
      const maxAttempts = 30;
      while (receipt == null && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 2));
        receipt = await _client.getTransactionReceipt(txHash);
        attempts++;
      }
      return receipt;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.dispose();
}
