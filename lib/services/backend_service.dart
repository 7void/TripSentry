import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tourist_record.dart';

class BackendService {
  // Use the actual working URL from BackendMintService
  static const String _baseUrl = 'http://172.20.188.199:3000/api';
  static const String _apiKey =
      'b74a90d9569eb50c5062bdfea78555c82696054b4de1fc224c622da6467358ba';

  static const String _applicationIdKey = 'tourist_application_id';
  static const String _touristHashKey = 'tourist_id_hash';

  // Increased timeout for blockchain operations
  static const Duration _defaultTimeout = Duration(minutes: 8);

  late SharedPreferences _prefs;
  // ignore: unused_field
  String? _authToken;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _authToken = _prefs.getString('auth_token');
  }

  // Check backend health
  Future<bool> checkHealth() async {
    try {
      print('Checking backend health...');
      final url = Uri.parse('http://172.20.188.199:3000/health');
      final response = await http.get(url).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Health check timeout');
          return http.Response('timeout', 408);
        },
      );

      print('Health check response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Backend health check failed: $e');
      return false;
    }
  }

  // Get blockchain status
  Future<Map<String, dynamic>> getBlockchainStatus() async {
    try {
      final url = Uri.parse('$_baseUrl/blockchain-status');
      final headers = await _authHeaders();

      final response = await http.get(url, headers: headers).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout checking blockchain status');
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get blockchain status');
      }
    } catch (e) {
      print('Error getting blockchain status: $e');
      throw Exception('Cannot check blockchain connection: $e');
    }
  }

  // Main function to create Tourist ID (mint NFT)
  Future<Map<String, dynamic>> createTouristID({
    required String touristAddress,
    required String touristIdHash,
    required DateTime validUntil,
    required String metadataCID,
    String issuerInfo = 'Government Tourism Authority',
  }) async {
    try {
      print('=== CREATING TOURIST ID ===');
      print('Tourist Address: $touristAddress');
      print('Tourist ID Hash: $touristIdHash');
      print('Valid Until: $validUntil');
      print('Metadata CID: $metadataCID');
      print('Issuer Info: $issuerInfo');

      final url = Uri.parse('$_baseUrl/mint-id');

      final headers = await _authHeaders(contentTypeJson: true);

      final body = {
        'touristAddress': touristAddress,
        'touristIdHash': touristIdHash,
        'validUntil': validUntil.toIso8601String(),
        'metadataCID': metadataCID,
        'issuerInfo': issuerInfo,
      };

      print('Sending request to: $url');
      print('Request headers: $headers');
      print('Request body: ${jsonEncode(body)}');

      final response = await http
          .post(
        url,
        headers: headers,
        body: jsonEncode(body),
      )
          .timeout(
        _defaultTimeout,
        onTimeout: () {
          throw Exception(
              'Request timeout after ${_defaultTimeout.inMinutes} minutes. '
              'This might be due to network congestion or blockchain processing delays.');
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          print('Tourist ID created successfully!');

          // Store the tourist hash and token ID locally
          final tokenId = responseData['data']['tokenId'].toString();
          await storeTouristHash(touristIdHash);
          await _prefs.setString('token_id', tokenId);

          return {
            'success': true,
            'data': responseData['data'],
            'message': 'Tourist ID created successfully',
          };
        } else {
          throw Exception(
              'Backend error: ${responseData['error'] ?? 'Unknown backend error'}');
        }
      } else {
        return _handleErrorResponse(response);
      }
    } on FormatException catch (e) {
      print('JSON parsing error: $e');
      throw Exception('Invalid response from server. Please try again.');
    } on http.ClientException catch (e) {
      print('Network error: $e');
      throw Exception(
          'Network connection failed. Please check your internet connection and try again.');
    } catch (e) {
      print('Error creating Tourist ID: $e');

      String errorMessage = e.toString();
      if (errorMessage.contains('Connection refused')) {
        errorMessage =
            'Cannot connect to backend server. Please ensure the server is running and accessible.';
      } else if (errorMessage.contains('timeout')) {
        errorMessage =
            'Request timed out. Blockchain operations may take longer during high network activity. Please try again.';
      } else if (errorMessage.contains('SocketException')) {
        errorMessage =
            'Network error. Please check your connection and try again.';
      }

      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Get Tourist ID details
  Future<TouristRecord?> getTouristID(int tokenId) async {
    try {
      final url = Uri.parse('$_baseUrl/tourist-id/$tokenId');
      final headers = await _authHeaders();

      print('Fetching tourist ID: $tokenId from $url');

      final response = await http.get(url, headers: headers).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout while fetching tourist ID');
        },
      );

      print('Get tourist ID response status: ${response.statusCode}');
      print('Get tourist ID response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final data = responseData['data'];
          return TouristRecord(
            touristIdHash: data['touristIdHash'],
            metadataCID: data['metadataCID'],
            validUntil: DateTime.parse(data['validUntil']),
            isActive: data['isActive'],
            touristAddress: data['touristAddress'],
            issuedAt: DateTime.parse(data['issuedAt']),
            issuerInfo: data['issuerInfo'],
          );
        }
        return null;
      } else if (response.statusCode == 404) {
        print('Tourist ID not found: $tokenId');
        return null;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'HTTP ${response.statusCode}: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error fetching Tourist ID: $e');
      rethrow;
    }
  }

  // Get all active Tourist IDs (for admin use)
  Future<Map<String, dynamic>> getAllActiveTouristIDs({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/tourist-ids?page=$page&limit=$limit');
      final headers = await _authHeaders();

      final response = await http.get(url, headers: headers).timeout(
        Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timeout while fetching tourist IDs');
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return responseData['data'];
        } else {
          throw Exception('Backend error: ${responseData['error']}');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'HTTP ${response.statusCode}: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error fetching all Tourist IDs: $e');
      rethrow;
    }
  }

  // Legacy methods for compatibility (these now just call the new methods)

  // Submit tourist ID application (now creates the NFT directly)
  Future<Map<String, dynamic>> submitTouristIDApplication({
    required TouristMetadata metadata,
    required DateTime intendedStayUntil,
    required String identityDocument,
    required String touristAddress,
    required String metadataCID,
  }) async {
    // Generate a hash for the tourist ID
    final touristIdHash = _generateTouristIdHash(metadata, identityDocument);

    return await createTouristID(
      touristAddress: touristAddress,
      touristIdHash: touristIdHash,
      validUntil: intendedStayUntil,
      metadataCID: metadataCID,
    );
  }

  // Check application status (now checks NFT status)
  Future<Map<String, dynamic>> checkApplicationStatus(
      String applicationId) async {
    try {
      // Try to parse applicationId as tokenId
      final tokenId = int.tryParse(applicationId);
      if (tokenId == null) {
        return {
          'success': false,
          'status': 'invalid',
          'message': 'Invalid application ID format',
        };
      }

      final touristRecord = await getTouristID(tokenId);
      if (touristRecord != null) {
        return {
          'success': true,
          'status': 'approved',
          'message': 'Tourist ID is active',
          'touristIdHash': touristRecord.touristIdHash,
          'tokenId': tokenId.toString(),
        };
      } else {
        return {
          'success': false,
          'status': 'not_found',
          'message': 'Tourist ID not found',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'status': 'error',
        'message': 'Error checking status: ${e.toString()}',
      };
    }
  }

  // Helper method to handle error responses
  Map<String, dynamic> _handleErrorResponse(http.Response response) {
    String errorMessage = 'Failed to create Tourist ID';

    if (response.statusCode == 408 || response.statusCode == 504) {
      errorMessage =
          'Request timeout. Blockchain operations may take longer during high network activity. Please try again in a few minutes.';
    } else if (response.statusCode == 429) {
      errorMessage = 'Rate limit exceeded. Please wait before trying again.';
    } else if (response.statusCode >= 500) {
      errorMessage =
          'Server error (${response.statusCode}). Please try again later.';
    } else {
      try {
        final errorData = jsonDecode(response.body);
        errorMessage =
            errorData['error'] ?? errorData['message'] ?? errorMessage;
      } catch (e) {
        // If we can't parse the error response, use the default message
      }
    }

    return {
      'success': false,
      'message': errorMessage,
    };
  }

  // Generate tourist ID hash
  String _generateTouristIdHash(
      TouristMetadata metadata, String identityDocument) {
    final String combined =
        '${metadata.name}${metadata.passportNumber}${metadata.aadhaarHash}$identityDocument';
    return combined.hashCode.abs().toString();
  }

  // Local storage methods
  Future<void> storeApplicationId(String applicationId) async {
    await _prefs.setString(_applicationIdKey, applicationId);
  }

  Future<String?> getStoredApplicationId() async {
    return _prefs.getString(_applicationIdKey);
  }

  Future<void> storeTouristHash(String hash) async {
    await _prefs.setString(_touristHashKey, hash);
  }

  Future<String?> getStoredTouristHash() async {
    return _prefs.getString(_touristHashKey);
  }

  Future<String?> getStoredTokenId() async {
    return _prefs.getString('token_id');
  }

  Future<void> clearStoredData() async {
    await _prefs.remove(_applicationIdKey);
    await _prefs.remove(_touristHashKey);
    await _prefs.remove('auth_token');
    await _prefs.remove('token_id');
  }

  void setAuthToken(String token) {
    _authToken = token;
    _prefs.setString('auth_token', token);
  }

  // Build headers with API key and optional Firebase ID token
  Future<Map<String, String>> _authHeaders(
      {bool contentTypeJson = false}) async {
    final Map<String, String> headers = {
      'x-api-key': _apiKey,
    };
    if (contentTypeJson) {
      headers['Content-Type'] = 'application/json';
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final idToken = await user.getIdToken();
        if (idToken != null && idToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $idToken';
        }
      } catch (_) {
        // Ignore token errors; backend can still accept API key
      }
    }
    return headers;
  }
}
