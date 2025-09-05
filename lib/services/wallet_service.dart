import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart'; // ADDED: provides EtherUnit and EtherAmount
import '../models/tourist_record.dart';
import 'blockchain_service.dart';

class WalletService {
  static const String _walletKey = 'tourist_wallet';
  static const String _touristRecordKey = 'tourist_record';
  static const String _tokenIdKey = 'token_id';
  
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final BlockchainService _blockchainService = BlockchainService();
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _blockchainService.initialize();
  }

  // Generate and save a new wallet
  Future<WalletInfo> createWallet() async {
    final wallet = _blockchainService.generateWallet();
    await _saveWallet(wallet);
    return wallet;
  }

  // Save wallet to secure storage
  Future<void> _saveWallet(WalletInfo wallet) async {
    final walletJson = jsonEncode(wallet.toJson());
    await _prefs?.setString(_walletKey, walletJson);
  }

  // Load wallet from storage
  Future<WalletInfo?> getWallet() async {
    final walletJson = _prefs?.getString(_walletKey);
    if (walletJson != null) {
      final walletMap = jsonDecode(walletJson) as Map<String, dynamic>;
      return WalletInfo.fromJson(walletMap);
    }
    return null;
  }

  // Check if wallet exists
  Future<bool> hasWallet() async {
    return _prefs?.containsKey(_walletKey) ?? false;
  }

  // Save tourist record
  Future<void> saveTouristRecord(TouristRecord record) async {
    final recordJson = jsonEncode(record.toJson());
    await _prefs?.setString(_touristRecordKey, recordJson);
  }

  // Get saved tourist record
  Future<TouristRecord?> getTouristRecord() async {
    final recordJson = _prefs?.getString(_touristRecordKey);
    if (recordJson != null) {
      final recordMap = jsonDecode(recordJson) as Map<String, dynamic>;
      return TouristRecord.fromJson(recordMap);
    }
    return null;
  }

  // Save token ID
  Future<void> saveTokenId(int tokenId) async {
    await _prefs?.setInt(_tokenIdKey, tokenId);
  }

  // Get saved token ID
  Future<int?> getTokenId() async {
    return _prefs?.getInt(_tokenIdKey);
  }

  // Clear all stored data
  Future<void> clearWallet() async {
    await _prefs?.remove(_walletKey);
    await _prefs?.remove(_touristRecordKey);
    await _prefs?.remove(_tokenIdKey);
  }

  // Get wallet balance in ETH
  Future<String> getWalletBalance() async {
    final wallet = await getWallet();
    if (wallet != null) {
      final balance = await _blockchainService.getEthBalance(wallet.address);
      return balance.getValueInUnit(EtherUnit.ether).toString();
    }
    return '0.0';
  }

  // Check if user has active Tourist ID
  Future<bool> hasActiveTouristID() async {
    final tokenId = await getTokenId();
    if (tokenId != null) {
      return await _blockchainService.isValidTouristID(tokenId);
    }
    return false;
  }

  // Check if Tourist ID is expired
  Future<bool> isTouristIDExpired() async {
    final tokenId = await getTokenId();
    if (tokenId != null) {
      return await _blockchainService.isExpired(tokenId);
    }
    return true;
  }

  // Get current tourist record from blockchain
  Future<TouristRecord?> getCurrentTouristRecord() async {
    final tokenId = await getTokenId();
    if (tokenId != null) {
      return await _blockchainService.getTouristRecord(tokenId);
    }
    return null;
  }

  // Update metadata CID
  Future<String?> updateTouristMetadata({
    required String newMetadataCID,
  }) async {
    final wallet = await getWallet();
    final tokenId = await getTokenId();
    
    if (wallet != null && tokenId != null) {
      try {
        final txHash = await _blockchainService.updateMetadata(
          tokenId: tokenId,
          newMetadataCID: newMetadataCID,
          touristPrivateKey: wallet.privateKey,
        );
        return txHash;
      } catch (e) {
        print('Error updating metadata: $e');
        return null;
      }
    }
    return null;
  }

  // Delete expired Tourist ID
  Future<String?> deleteExpiredTouristID() async {
    final wallet = await getWallet();
    final tokenId = await getTokenId();
    
    if (wallet != null && tokenId != null) {
      try {
        final txHash = await _blockchainService.deleteExpiredTouristID(
          tokenId: tokenId,
          privateKey: wallet.privateKey,
        );
        
        // Clear local data after successful deletion
        await clearWallet();
        
        return txHash;
      } catch (e) {
        print('Error deleting expired ID: $e');
        return null;
      }
    }
    return null;
  }

  // Wait for transaction confirmation
  Future<bool> waitForTransactionConfirmation(String txHash) async {
    final receipt = await _blockchainService.waitForTransactionReceipt(txHash);
    return receipt != null && receipt.status == true;
  }
}
