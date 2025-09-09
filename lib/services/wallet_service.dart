import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tourist_record.dart';
import 'blockchain_service.dart';

class WalletService {
  static const String _touristRecordKey = 'tourist_record';
  static const String _tokenIdKey = 'token_id';

  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final BlockchainService _blockchainService = BlockchainService();
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    // Don't initialize blockchain service here to avoid circular dependency
    // It will be initialized separately in the provider
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
    await _prefs?.remove(_touristRecordKey);
    await _prefs?.remove(_tokenIdKey);
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

  // Note: Metadata updates and Tourist ID deletion now handled by backend service
  // since we no longer have tourist wallets with private keys

  // Wait for transaction confirmation
  Future<bool> waitForTransactionConfirmation(String txHash) async {
    final receipt = await _blockchainService.waitForTransactionReceipt(txHash);
    return receipt != null && receipt.status == true;
  }
}
