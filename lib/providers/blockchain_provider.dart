import 'package:flutter/foundation.dart';
import '../models/tourist_record.dart';
import '../services/wallet_service.dart';
import '../services/blockchain_service.dart';
import '../services/ipfs_service.dart';

enum BlockchainStatus {
  uninitialized,
  initializing,
  ready,
  error,
  loading,
  transactionPending,
}

class BlockchainProvider with ChangeNotifier {
  final WalletService _walletService = WalletService();
  final BlockchainService _blockchainService = BlockchainService();
  final IPFSService _ipfsService = IPFSService();

  BlockchainStatus _status = BlockchainStatus.uninitialized;
  WalletInfo? _wallet;
  TouristRecord? _touristRecord;
  int? _tokenId;
  String _errorMessage = '';
  String _transactionHash = '';
  bool _hasActiveTouristID = false;

  // Getters
  BlockchainStatus get status => _status;
  WalletInfo? get wallet => _wallet;
  TouristRecord? get touristRecord => _touristRecord;
  int? get tokenId => _tokenId;
  String get errorMessage => _errorMessage;
  String get transactionHash => _transactionHash;
  bool get hasActiveTouristID => _hasActiveTouristID;
  bool get isInitialized => _status != BlockchainStatus.uninitialized;
  bool get isReady => _status == BlockchainStatus.ready;
  bool get isLoading => _status == BlockchainStatus.loading;
  bool get hasError => _status == BlockchainStatus.error;

  String get walletAddress => _wallet?.address ?? '';
  String get shortWalletAddress {
    if (_wallet?.address.isNotEmpty == true) {
      final address = _wallet!.address;
      return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
    }
    return '';
  }

  // Initialize the blockchain services
  Future<void> initialize() async {
    _setStatus(BlockchainStatus.initializing);
    
    try {
      await _walletService.initialize();
      
      // Check if wallet exists
      final hasWallet = await _walletService.hasWallet();
      if (hasWallet) {
        _wallet = await _walletService.getWallet();
        _tokenId = await _walletService.getTokenId();
        _touristRecord = await _walletService.getTouristRecord();
        _hasActiveTouristID = await _walletService.hasActiveTouristID();
      }

      _setStatus(BlockchainStatus.ready);
    } catch (e) {
      _setError('Failed to initialize blockchain services: $e');
    }
  }

  // Create a new wallet
  Future<void> createWallet() async {
    _setStatus(BlockchainStatus.loading);
    
    try {
      _wallet = await _walletService.createWallet();
      _setStatus(BlockchainStatus.ready);
    } catch (e) {
      _setError('Failed to create wallet: $e');
    }
  }

  // Mint Tourist ID
  Future<bool> mintTouristID({
    required TouristMetadata metadata,
    required DateTime validUntil,
    required String ownerPrivateKey,
    required String identityDocument, // Aadhaar or Passport number
  }) async {
    if (_wallet == null) {
      _setError('Wallet not initialized');
      return false;
    }

    _setStatus(BlockchainStatus.loading);

    try {
      // Upload metadata to IPFS
      final metadataCID = await _ipfsService.uploadMetadata(metadata);
      if (metadataCID == null) {
        _setError('Failed to upload metadata to IPFS');
        return false;
      }

      // Generate tourist ID hash
      final touristIdHash = _blockchainService.generateTouristIdHash(identityDocument);

      // Mint NFT on blockchain
      _setStatus(BlockchainStatus.transactionPending);
      final txHash = await _blockchainService.mintTouristID(
        touristAddress: _wallet!.address,
        touristIdHash: touristIdHash,
        validUntil: validUntil,
        metadataCID: metadataCID,
        ownerPrivateKey: ownerPrivateKey,
      );

      _transactionHash = txHash;

      // Wait for confirmation
      final isConfirmed = await _walletService.waitForTransactionConfirmation(txHash);
      if (!isConfirmed) {
        _setError('Transaction failed or timeout');
        return false;
      }

      // Get token ID from blockchain
      final tokenId = await _blockchainService.getTokenIdByTouristHash(touristIdHash);
      if (tokenId == null) {
        _setError('Failed to retrieve token ID');
        return false;
      }

      _tokenId = tokenId;
      await _walletService.saveTokenId(tokenId);

      // Get and save tourist record
      final record = await _blockchainService.getTouristRecord(tokenId);
      if (record != null) {
        _touristRecord = record;
        await _walletService.saveTouristRecord(record);
      }

      _hasActiveTouristID = true;
      _setStatus(BlockchainStatus.ready);
      return true;

    } catch (e) {
      _setError('Failed to mint Tourist ID: $e');
      return false;
    }
  }

  // Update metadata
  Future<bool> updateMetadata(TouristMetadata newMetadata) async {
    if (_wallet == null || _tokenId == null) {
      _setError('Wallet or Token ID not initialized');
      return false;
    }

    _setStatus(BlockchainStatus.loading);

    try {
      // Upload new metadata to IPFS
      final newMetadataCID = await _ipfsService.uploadMetadata(newMetadata);
      if (newMetadataCID == null) {
        _setError('Failed to upload new metadata to IPFS');
        return false;
      }

      // Update metadata on blockchain
      _setStatus(BlockchainStatus.transactionPending);
      final txHash = await _walletService.updateTouristMetadata(
        newMetadataCID: newMetadataCID,
      );

      if (txHash == null) {
        _setError('Failed to update metadata on blockchain');
        return false;
      }

      _transactionHash = txHash;

      // Wait for confirmation
      final isConfirmed = await _walletService.waitForTransactionConfirmation(txHash);
      if (!isConfirmed) {
        _setError('Transaction failed or timeout');
        return false;
      }

      // Refresh tourist record
      await refreshTouristRecord();
      _setStatus(BlockchainStatus.ready);
      return true;

    } catch (e) {
      _setError('Failed to update metadata: $e');
      return false;
    }
  }

  // Refresh tourist record from blockchain
  Future<void> refreshTouristRecord() async {
    if (_tokenId == null) return;

    try {
      final record = await _blockchainService.getTouristRecord(_tokenId!);
      if (record != null) {
        _touristRecord = record;
        await _walletService.saveTouristRecord(record);
        _hasActiveTouristID = record.isValid;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing tourist record: $e');
    }
  }

  // Check if Tourist ID is expired
  Future<bool> checkIfExpired() async {
    if (_tokenId == null) return true;
    
    final isExpired = await _walletService.isTouristIDExpired();
    if (isExpired && _hasActiveTouristID) {
      _hasActiveTouristID = false;
      notifyListeners();
    }
    return isExpired;
  }

  // Delete expired Tourist ID
  Future<bool> deleteExpiredTouristID() async {
    if (_tokenId == null) {
      _setError('No Tourist ID found');
      return false;
    }

    _setStatus(BlockchainStatus.loading);

    try {
      _setStatus(BlockchainStatus.transactionPending);
      final txHash = await _walletService.deleteExpiredTouristID();
      
      if (txHash == null) {
        _setError('Failed to delete expired Tourist ID');
        return false;
      }

      _transactionHash = txHash;

      // Wait for confirmation
      final isConfirmed = await _walletService.waitForTransactionConfirmation(txHash);
      if (!isConfirmed) {
        _setError('Transaction failed or timeout');
        return false;
      }

      // Clear local data
      _tokenId = null;
      _touristRecord = null;
      _hasActiveTouristID = false;
      _setStatus(BlockchainStatus.ready);
      return true;

    } catch (e) {
      _setError('Failed to delete expired Tourist ID: $e');
      return false;
    }
  }

  // Get wallet balance
  Future<String> getWalletBalance() async {
    try {
      return await _walletService.getWalletBalance();
    } catch (e) {
      print('Error getting wallet balance: $e');
      return '0.0';
    }
  }

  // Get metadata from IPFS
  Future<TouristMetadata?> getMetadataFromIPFS() async {
    if (_touristRecord?.metadataCID.isEmpty == true) return null;

    try {
      return await _ipfsService.getMetadata(_touristRecord!.metadataCID);
    } catch (e) {
      print('Error getting metadata from IPFS: $e');
      return null;
    }
  }

  // Clear wallet and reset state
  Future<void> clearWallet() async {
    try {
      await _walletService.clearWallet();
      _wallet = null;
      _tokenId = null;
      _touristRecord = null;
      _hasActiveTouristID = false;
      _transactionHash = '';
      _setStatus(BlockchainStatus.ready);
    } catch (e) {
      _setError('Failed to clear wallet: $e');
    }
  }

  // Private helper methods
  void _setStatus(BlockchainStatus status) {
    _status = status;
    if (status != BlockchainStatus.error) {
      _errorMessage = '';
    }
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = BlockchainStatus.error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    if (_status == BlockchainStatus.error) {
      _errorMessage = '';
      _status = BlockchainStatus.ready;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Clean up resources if needed
    super.dispose();
  }
}