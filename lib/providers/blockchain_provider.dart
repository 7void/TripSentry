import 'package:flutter/foundation.dart';
import '../models/tourist_record.dart';
import '../services/backend_service.dart'; // Only need this one now
import '../services/blockchain_service.dart';
import '../services/ipfs_service.dart';
import '../services/wallet_service.dart';

enum ApplicationStatus {
  notSubmitted,
  submitted,
  underReview,
  approved,
  rejected,
  nftMinted,
  expired,
}

enum BlockchainStatus {
  uninitialized,
  initializing,
  ready,
  error,
  loading,
  transactionPending,
}

class BlockchainProvider with ChangeNotifier {
  // Only use the consolidated BackendService
  final BackendService _backendService = BackendService();
  final BlockchainService _blockchainService = BlockchainService();
  final IPFSService _ipfsService = IPFSService();
  final WalletService _walletService = WalletService();

  BlockchainStatus _status = BlockchainStatus.uninitialized;
  ApplicationStatus _applicationStatus = ApplicationStatus.notSubmitted;
  TouristRecord? _touristRecord;
  int? _tokenId;
  String _errorMessage = '';
  String _applicationId = '';
  bool _hasActiveTouristID = false;
  String? _touristIdHash; // Store the hash for tracking
  String _transactionHash = '';

  // Getters
  BlockchainStatus get status => _status;
  ApplicationStatus get applicationStatus => _applicationStatus;
  TouristRecord? get touristRecord => _touristRecord;
  int? get tokenId => _tokenId;
  String get errorMessage => _errorMessage;
  String get applicationId => _applicationId;
  bool get hasActiveTouristID => _hasActiveTouristID;
  bool get isInitialized => _status != BlockchainStatus.uninitialized;
  bool get isReady => _status == BlockchainStatus.ready;
  bool get isLoading =>
      _status == BlockchainStatus.loading ||
      _status == BlockchainStatus.initializing;
  bool get hasError => _status == BlockchainStatus.error;
  String get transactionHash => _transactionHash;

  // Initialize the services
  Future<void> initialize() async {
    if (_status == BlockchainStatus.initializing) {
      return; // Already initializing
    }

    _setStatus(BlockchainStatus.initializing);

    try {
      // Initialize services
      await _backendService.initialize();
      await _walletService.initialize();

      // Try to initialize blockchain service, but don't fail if it doesn't work
      try {
        await _blockchainService.initialize();
      } catch (e) {
        print('Blockchain service initialization failed: $e');
        // Continue without blockchain functionality
      }

      // Load existing tourist data
      try {
        _tokenId = await _walletService.getTokenId();
        _touristRecord = await _walletService.getTouristRecord();
        if (_tokenId != null && _touristRecord != null) {
          _hasActiveTouristID = true;
        }
      } catch (e) {
        print('Error loading tourist data: $e');
        // Clear any corrupted data
        await _walletService.clearWallet();
        _tokenId = null;
        _touristRecord = null;
        _hasActiveTouristID = false;
      }

      // Check if user has any existing application or tourist ID
      await _checkExistingApplication();

      _setStatus(BlockchainStatus.ready);
    } catch (e) {
      _setError('Failed to initialize services: ${e.toString()}');
      rethrow;
    }
  }

  // Initialize blockchain services (alias for initialize)
  Future<void> initializeBlockchainServices() async {
    await initialize();
  }

  // Clear tourist data
  Future<void> clearWallet() async {
    try {
      await _walletService.clearWallet();
      _touristRecord = null;
      _tokenId = null;
      _hasActiveTouristID = false;
      _touristIdHash = null;
      _applicationStatus = ApplicationStatus.notSubmitted;
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear tourist data: ${e.toString()}');
    }
  }

  // FIXED: Mint Tourist ID using the consolidated backend service
  Future<bool> mintTouristID({
    required TouristMetadata metadata,
    required DateTime validUntil,
    required String identityDocument,
  }) async {
    print('=== STARTING MINT PROCESS ===');
    print('Valid Until: $validUntil');
    print('Identity Document: $identityDocument');

    _setStatus(BlockchainStatus.loading);
    _transactionHash = '';

    try {
      // Check backend health first
      print('Checking backend health...');
      final isHealthy = await _backendService.checkHealth();
      if (!isHealthy) {
        _setError('Backend server is not responding. Please try again later.');
        return false;
      }
      print('Backend health check passed');

      // Upload metadata to IPFS
      print('Uploading metadata to IPFS...');
      final metadataCID = await _ipfsService.uploadMetadata(metadata);
      if (metadataCID == null) {
        _setError('Failed to upload metadata to IPFS');
        return false;
      }
      print('Metadata uploaded to IPFS: $metadataCID');

      // Generate tourist ID hash
      final touristIdHash =
          _blockchainService.generateTouristIdHash(identityDocument);
      print('Generated tourist ID hash: $touristIdHash');

      // Set status to transaction pending
      _setStatus(BlockchainStatus.transactionPending);

      // Resolve central wallet address to satisfy backend validation
      String? resolvedWallet = await _blockchainService.getCentralWallet();
      if (resolvedWallet == null || !resolvedWallet.startsWith('0x')) {
        // Fallback: ask backend for governmentAddress
        try {
          final status = await _backendService.getBlockchainStatus();
          final governmentAddress = status['governmentAddress'] as String?;
          if (governmentAddress != null && governmentAddress.startsWith('0x')) {
            resolvedWallet = governmentAddress;
          }
        } catch (e) {
          // ignore, handled below
        }
      }

      if (resolvedWallet == null || !resolvedWallet.startsWith('0x')) {
        _setError('Central wallet address not available');
        return false;
      }
      print('Using touristAddress: $resolvedWallet');

      // Use the consolidated backend service's createTouristID method
      print('Creating Tourist ID through backend...');
      final result = await _backendService.createTouristID(
        touristAddress: resolvedWallet,
        touristIdHash: touristIdHash,
        validUntil: validUntil,
        metadataCID: metadataCID,
      );

      print('Backend result: $result');

      if (result['success'] == true) {
        final data = result['data'];
        _transactionHash = data['transactionHash'] ?? '';
        final tokenId = data['tokenId'];

        if (tokenId != null) {
          _tokenId = tokenId;
          _touristIdHash = touristIdHash;
          await _walletService.saveTokenId(tokenId);

          // Get the tourist record from backend
          print('Fetching tourist record...');
          final record = await _backendService.getTouristID(tokenId);
          if (record != null) {
            _touristRecord = record;
            _hasActiveTouristID = true;
            _applicationStatus = ApplicationStatus.nftMinted;
            await _walletService.saveTouristRecord(record);
            print('Tourist record saved successfully');
          }
        }

        _setStatus(BlockchainStatus.ready);
        print('=== MINT PROCESS COMPLETED SUCCESSFULLY ===');
        return true;
      } else {
        _setError(result['message'] ?? 'Failed to create Tourist ID');
        return false;
      }
    } catch (e) {
      print('=== MINT PROCESS FAILED ===');
      print('Error: $e');
      _setError('Failed to mint Tourist ID: ${e.toString()}');
      return false;
    }
  }

  // Delete expired Tourist ID (now handled by backend)
  Future<bool> deleteExpiredTouristID() async {
    if (_tokenId == null) {
      _setError('No Tourist ID found');
      return false;
    }

    _setStatus(BlockchainStatus.loading);

    try {
      // For now, just clear local data since backend doesn't have delete endpoint
      // The expired Tourist ID will remain on blockchain but won't be accessible locally
      _tokenId = null;
      _touristRecord = null;
      _hasActiveTouristID = false;
      _touristIdHash = null;
      await _walletService.clearWallet();

      _setStatus(BlockchainStatus.ready);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete Tourist ID: ${e.toString()}');
      return false;
    }
  }

  // Check for existing application or tourist ID
  Future<void> _checkExistingApplication() async {
    try {
      // Check if there's a stored application ID
      final storedAppId = await _backendService.getStoredApplicationId();
      if (storedAppId != null) {
        _applicationId = storedAppId;
        await checkApplicationStatus();
      }

      // Check if there's a stored tourist ID hash
      final storedHash = await _backendService.getStoredTouristHash();
      if (storedHash != null) {
        _touristIdHash = storedHash;
        await _checkTouristIDStatus();
      }

      // Check if there's a stored token ID
      final storedTokenId = await _backendService.getStoredTokenId();
      if (storedTokenId != null) {
        _tokenId = int.tryParse(storedTokenId);
        if (_tokenId != null) {
          final record = await _backendService.getTouristID(_tokenId!);
          if (record != null) {
            _touristRecord = record;
            _hasActiveTouristID = true;
            _applicationStatus = ApplicationStatus.nftMinted;
          }
        }
      }
    } catch (e) {
      print('Warning: Could not check existing application: $e');
    }
  }

  // Submit tourist ID application (now creates NFT directly)
  Future<bool> submitTouristIDApplication({
    required String fullName,
    required String dateOfBirth,
    required String nationality,
    required String identityDocument,
    required String identityType,
    required String phoneNumber,
    required String email,
    required String purposeOfVisit,
    required DateTime intendedStayUntil,
    String? profileImageBase64,
    Map<String, String>? additionalData,
  }) async {
    if (_applicationStatus == ApplicationStatus.submitted ||
        _applicationStatus == ApplicationStatus.underReview) {
      _setError('Application already submitted. Please wait for review.');
      return false;
    }

    if (_hasActiveTouristID) {
      _setError('You already have an active Tourist ID');
      return false;
    }

    // Create metadata object
    final metadata = TouristMetadata(
      name: fullName,
      passportNumber: identityDocument,
      aadhaarHash: identityType == 'aadhaar' ? identityDocument : '',
      nationality: nationality,
      dateOfBirth: DateTime.parse(dateOfBirth),
      phoneNumber: phoneNumber,
      emergencyContact: 'Emergency Contact',
      emergencyPhone: phoneNumber,
      itinerary: [],
      profileImageCID: profileImageBase64 ?? '',
      issuedAt: DateTime.now(),
    );

    // Use the mintTouristID method which now handles everything
    return await mintTouristID(
      metadata: metadata,
      validUntil: intendedStayUntil,
      identityDocument: identityDocument,
    );
  }

  // Check application status
  Future<void> checkApplicationStatus() async {
    if (_applicationId.isEmpty) return;

    try {
      final statusResult =
          await _backendService.checkApplicationStatus(_applicationId);

      final newStatus = _parseApplicationStatus(statusResult['status']);
      if (newStatus != _applicationStatus) {
        _applicationStatus = newStatus;

        // If approved and NFT is minted, get the tourist record
        if (_applicationStatus == ApplicationStatus.nftMinted) {
          final touristHash = statusResult['touristIdHash'];
          if (touristHash != null) {
            _touristIdHash = touristHash;
            await _backendService.storeTouristHash(touristHash);
            await _checkTouristIDStatus();
          }
        }

        notifyListeners();
      }
    } catch (e) {
      print('Error checking application status: $e');
    }
  }

  // Check tourist ID status from blockchain
  Future<void> _checkTouristIDStatus() async {
    if (_touristIdHash == null) return;

    try {
      // Get token ID from blockchain using the hash
      final tokenId =
          await _blockchainService.getTokenIdByTouristHash(_touristIdHash!);
      if (tokenId != null) {
        _tokenId = tokenId;

        // Check if it's still valid
        final isValid = await _blockchainService.isValidTouristID(tokenId);
        if (isValid) {
          _hasActiveTouristID = true;
          _applicationStatus = ApplicationStatus.nftMinted;

          // Get the tourist record from backend instead of blockchain service
          final record = await _backendService.getTouristID(tokenId);
          if (record != null) {
            _touristRecord = record;
          }
        } else {
          // Check if expired
          final isExpired = await _blockchainService.isExpired(tokenId);
          if (isExpired) {
            _applicationStatus = ApplicationStatus.expired;
            _hasActiveTouristID = false;
          }
        }
      }
    } catch (e) {
      print('Error checking tourist ID status: $e');
      // If we can't find the token, it might have been deleted
      _hasActiveTouristID = false;
    }
  }

  // Parse application status from backend
  ApplicationStatus _parseApplicationStatus(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return ApplicationStatus.submitted;
      case 'under_review':
      case 'reviewing':
        return ApplicationStatus.underReview;
      case 'approved':
        return ApplicationStatus.approved;
      case 'rejected':
        return ApplicationStatus.rejected;
      case 'nft_minted':
      case 'minted':
        return ApplicationStatus.nftMinted;
      case 'expired':
        return ApplicationStatus.expired;
      default:
        return ApplicationStatus.notSubmitted;
    }
  }

  // Update personal details (if NFT is minted and active)
  Future<bool> updatePersonalDetails({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String purposeOfVisit,
    String? profileImageBase64,
    Map<String, String>? additionalData,
  }) async {
    if (!_hasActiveTouristID || _tokenId == null) {
      _setError('No active Tourist ID found');
      return false;
    }

    _setStatus(BlockchainStatus.loading);

    try {
      // Get current metadata from IPFS
      final currentMetadata = await getMetadataFromIPFS();
      if (currentMetadata == null) {
        _setError('Could not retrieve current metadata');
        return false;
      }

      // This method doesn't exist in the consolidated service, so we'll skip this for now
      // or you can implement it if needed
      _setError('Update functionality not yet implemented');
      return false;
    } catch (e) {
      _setError('Failed to update details: ${e.toString()}');
      return false;
    }
  }

  // Refresh tourist record from blockchain
  Future<void> refreshTouristRecord() async {
    if (_tokenId == null) return;

    try {
      final record = await _backendService.getTouristID(_tokenId!);
      if (record != null) {
        _touristRecord = record;
        _hasActiveTouristID = record.isActive;

        if (!_hasActiveTouristID) {
          // Check if expired using blockchain service
          final isExpired = await _blockchainService.isExpired(_tokenId!);
          if (isExpired) {
            _applicationStatus = ApplicationStatus.expired;
          }
        }

        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing tourist record: $e');
      // If we can't get the record, it might have been deleted
      _hasActiveTouristID = false;
      notifyListeners();
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

  // Check if Tourist ID is expired
  Future<bool> checkIfExpired() async {
    if (_tokenId == null) return true;

    try {
      final isExpired = await _blockchainService.isExpired(_tokenId!);
      if (isExpired && _hasActiveTouristID) {
        _hasActiveTouristID = false;
        _applicationStatus = ApplicationStatus.expired;
        notifyListeners();
      }
      return isExpired;
    } catch (e) {
      print('Error checking expiration: $e');
      return true;
    }
  }

  // Request deletion of expired Tourist ID - using backend service
  Future<bool> requestDeletion() async {
    if (_tokenId == null) {
      _setError('No Tourist ID found');
      return false;
    }

    _setStatus(BlockchainStatus.loading);

    try {
      // This method doesn't exist in consolidated service, but we can clear local data
      await _clearLocalData();
      _setStatus(BlockchainStatus.ready);
      return true;
    } catch (e) {
      _setError('Failed to delete Tourist ID: ${e.toString()}');
      return false;
    }
  }

  // Clear all local data
  Future<void> _clearLocalData() async {
    _applicationId = '';
    _tokenId = null;
    _touristRecord = null;
    _hasActiveTouristID = false;
    _touristIdHash = null;
    _applicationStatus = ApplicationStatus.notSubmitted;

    await _backendService.clearStoredData();
  }

  // Reset application (start over)
  Future<void> resetApplication() async {
    try {
      await _clearLocalData();
      // Ensure wallet-specific keys (e.g., 'tourist_record', int 'token_id') are also cleared
      await _walletService.clearWallet();
      _setStatus(BlockchainStatus.ready);
    } catch (e) {
      _setError('Failed to reset application: ${e.toString()}');
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

  // Additional utility methods matching your BlockchainService

  // Get central wallet address
  Future<String?> getCentralWalletAddress() async {
    try {
      return await _blockchainService.getCentralWallet();
    } catch (e) {
      print('Error getting central wallet address: $e');
      return null;
    }
  }

  // Get tourist address associated with token ID
  Future<String?> getTouristAddressForToken(int tokenId) async {
    try {
      return await _blockchainService.getTouristOf(tokenId);
    } catch (e) {
      print('Error getting tourist address: $e');
      return null;
    }
  }

  // Get all active tourist IDs (for admin/government dashboard)
  Future<Map<int, String>?> getAllActiveTouristIDs() async {
    try {
      return await _blockchainService.getAllActiveTouristIDs();
    } catch (e) {
      print('Error getting all active tourist IDs: $e');
      return null;
    }
  }

  // Get total count of active IDs
  Future<int> getTotalActiveIDsCount() async {
    try {
      return await _blockchainService.getTotalActiveIDs();
    } catch (e) {
      print('Error getting total active IDs count: $e');
      return 0;
    }
  }

  // Get complete tourist information
  Future<Map<String, dynamic>?> getCompleteTouristInfo() async {
    if (_tokenId == null) return null;

    try {
      return await _blockchainService.getCompleteTouristInfo(_tokenId!);
    } catch (e) {
      print('Error getting complete tourist info: $e');
      return null;
    }
  }

  // Check if current user has any tourist ID by generating potential hash
  Future<bool> checkForExistingTouristID(String identityDocument) async {
    try {
      final hash = _blockchainService.generateTouristIdHash(identityDocument);
      final tokenId = await _blockchainService.getTokenIdByTouristHash(hash);

      if (tokenId != null) {
        // Found existing ID, update local state
        _tokenId = tokenId;
        _touristIdHash = hash;
        await _backendService.storeTouristHash(hash);
        await _checkTouristIDStatus();
        return true;
      }
      return false;
    } catch (e) {
      print('Error checking for existing tourist ID: $e');
      return false;
    }
  }

  // Verify NFT ownership (should return central wallet as owner)
  Future<String?> getNFTOwner() async {
    if (_tokenId == null) return null;

    try {
      return await _blockchainService.getOwnerOf(_tokenId!);
    } catch (e) {
      print('Error getting NFT owner: $e');
      return null;
    }
  }

}
