import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';
import '../models/tourist_record.dart';

/// Result object for IPFS uploads.
class IPFSUploadResult {
  final String cid;
  final String gatewayUrl;
  final Map<String, dynamic>? pinnedMetadata; // The content actually pinned (sanitized)
  IPFSUploadResult({required this.cid, required this.gatewayUrl, this.pinnedMetadata});
}

class IPFSService {
  // Base Pinata API (configurable in future if multi-provider)
  static const String _baseUrl = 'https://api.pinata.cloud';

  // Environment-loaded credentials (never hardcode secrets!)
  // JWT-only authentication (API key/secret removed by request)
  String? get _jwtRaw => dotenv.env['PINATA_JWT'];

  bool get _hasValidJwt {
  if (_jwtRaw == null) return false;
    final t = _jwtRaw!.trim();
    if (t.isEmpty) return false;
    // Basic JWT format check (three segments)
    final parts = t.split('.');
    if (parts.length != 3) {
      // ignore: avoid_print
      print('[IPFSService] PINATA_JWT appears malformed (expected 3 segments). Falling back to key/secret if available.');
      return false;
    }
    return true;
  }

  // Gateways: primary + fallback(s)
  List<String> get _gateways {
    final primary = dotenv.env['IPFS_PRIMARY_GATEWAY'] ?? 'https://gateway.pinata.cloud/ipfs/';
    final fallback = dotenv.env['IPFS_FALLBACK_GATEWAY'] ?? 'https://ipfs.io/ipfs/';
    final extra = dotenv.env['IPFS_EXTRA_GATEWAYS']; // comma separated
    final list = <String>{primary, fallback};
    if (extra != null && extra.trim().isNotEmpty) {
      list.addAll(extra.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    return list.toList();
  }

  static final IPFSService _instance = IPFSService._internal();
  factory IPFSService() => _instance;
  IPFSService._internal();

  Map<String, String> get _headers {
    if (_hasValidJwt) {
      return {
        'Authorization': 'Bearer ${_jwtRaw!.trim()}',
        'Content-Type': 'application/json',
      };
    }
    throw StateError('PINATA_JWT missing or malformed (expected 3 segments).');
  }

  Map<String, String> get _fileHeaders {
    if (_hasValidJwt) {
      return {
        'Authorization': 'Bearer ${_jwtRaw!.trim()}',
      };
    }
    throw StateError('PINATA_JWT missing or malformed for file upload.');
  }

  // ---- Internal Helpers ----
  String _hashValue(String value) {
    if (value.isEmpty) return value;
    final bytes = utf8.encode(value.trim());
    final digest = sha256.convert(bytes); // acceptable for anonymization; keccak optional
    return 'sha256:${digest.toString()}';
  }

  Map<String, dynamic> _buildSanitizedMetadata(TouristMetadata metadata, {bool hashSensitive = true}) {
    // Choose which fields to hash (PII / contact data)
    final phone = hashSensitive ? _hashValue(metadata.phoneNumber) : metadata.phoneNumber;
    final emergencyPhone = hashSensitive ? _hashValue(metadata.emergencyPhone) : metadata.emergencyPhone;
    final passport = hashSensitive ? _hashValue(metadata.passportNumber) : metadata.passportNumber;
    final emergencyContact = hashSensitive ? _hashValue(metadata.emergencyContact) : metadata.emergencyContact;
    final aadhaar = metadata.aadhaarHash.isNotEmpty ? (hashSensitive ? _hashValue(metadata.aadhaarHash) : metadata.aadhaarHash) : '';

    return {
      'name': 'Tourist ID - ${metadata.name}',
      'description': 'Digital Tourist ID (non-sensitive public subset)',
      'image': metadata.profileImageCID.isNotEmpty ? 'ipfs://${metadata.profileImageCID}' : null,
      'attributes': [
        {'trait_type': 'Nationality', 'value': metadata.nationality},
        {'trait_type': 'Hashed Passport', 'value': passport},
        if (aadhaar.isNotEmpty) {'trait_type': 'Hashed Aadhaar', 'value': aadhaar},
        {'trait_type': 'Hashed Phone', 'value': phone},
        {'trait_type': 'Hashed Emergency Contact', 'value': emergencyContact},
        {'trait_type': 'Hashed Emergency Phone', 'value': emergencyPhone},
        {'trait_type': 'DOB', 'value': metadata.dateOfBirth.toIso8601String()},
      ],
      'issuedAt': metadata.issuedAt.toIso8601String(),
      'itineraryLength': metadata.itinerary.length,
      'schema': 'tourist-id-v1',
    }..removeWhere((k, v) => v == null);
  }

  Future<http.Response> _postJson(String path, Map<String, dynamic> body, {int attempt = 0}) async {
    final maxAttempts = 3;
    final backoffMs = 400 * pow(2, attempt); // exponential backoff
    try {
      final resp = await http
          .post(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode >= 500 && attempt < maxAttempts - 1) {
        await Future.delayed(Duration(milliseconds: backoffMs.toInt()));
        return _postJson(path, body, attempt: attempt + 1);
      }
      return resp;
    } catch (e) {
      if (attempt < maxAttempts - 1) {
        await Future.delayed(Duration(milliseconds: backoffMs.toInt()));
        return _postJson(path, body, attempt: attempt + 1);
      }
      rethrow;
    }
  }

  /// Upload sanitized public metadata for a Tourist ID (hashes PII by default).
  /// Returns CID or null on failure (legacy convenience).
  @Deprecated('Use uploadMetadataDetailed for structured result')
  Future<String?> uploadMetadata(TouristMetadata metadata, {bool hashSensitive = true}) async {
    final res = await uploadMetadataDetailed(metadata, hashSensitive: hashSensitive);
    return res?.cid;
  }

  /// New structured metadata upload returning an IPFSUploadResult.
  Future<IPFSUploadResult?> uploadMetadataDetailed(TouristMetadata metadata, {bool hashSensitive = true}) async {
    try {
      final sanitized = _buildSanitizedMetadata(metadata, hashSensitive: hashSensitive);
      final body = {
        'pinataContent': sanitized,
        'pinataMetadata': {
          'name': 'tourist-id-${metadata.passportNumber.isEmpty ? metadata.name : metadata.passportNumber}',
          'keyvalues': {
            'type': 'tourist-metadata-public',
            'nationality': metadata.nationality,
            'schema': 'v1'
          }
        }
      };

      final response = await _postJson('/pinning/pinJSONToIPFS', body);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final cid = responseData['IpfsHash'];
        return IPFSUploadResult(
          cid: cid,
            gatewayUrl: getGatewayUrl(cid),
            pinnedMetadata: sanitized,
        );
      } else {
        print('Failed to upload metadata: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading metadata to IPFS: $e');
      return null;
    }
  }

  // Upload file to IPFS
  Future<String?> uploadFile(Uint8List fileBytes, String filename, String contentType) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/pinning/pinFileToIPFS'),
      );

      request.headers.addAll(_fileHeaders);
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filename,
        ),
      );

      request.fields['pinataMetadata'] = jsonEncode({
        'name': filename,
        'keyvalues': {
          'type': contentType,
          'uploadedAt': DateTime.now().toIso8601String(),
        }
      });

      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(await response.stream.bytesToString());
        return responseData['IpfsHash'];
      } else {
        print('Failed to upload file: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading file to IPFS: $e');
      return null;
    }
  }

  // Upload image to IPFS
  Future<String?> uploadImage(Uint8List imageBytes, String filename) async {
    return await uploadFile(imageBytes, filename, 'image');
  }

  // Get content from IPFS
  Future<String?> getContent(String cid) async {
    for (final g in _gateways) {
      final url = '$g$cid';
      try {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
        if (resp.statusCode == 200) return resp.body;
      } catch (_) {
        // try next gateway
      }
    }
    print('All gateways failed for CID: $cid');
    return null;
  }

  // Get metadata from IPFS
  Future<TouristMetadata?> getMetadata(String cid) async {
    try {
      final content = await getContent(cid);
      if (content != null) {
        final jsonData = jsonDecode(content);
        if (jsonData['metadata'] != null) {
          return TouristMetadata.fromJson(jsonData['metadata']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting metadata from IPFS: $e');
      return null;
    }
  }

  // Get image bytes from IPFS
  Future<Uint8List?> getImageBytes(String cid) async {
    for (final g in _gateways) {
      final url = '$g$cid';
      try {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
        if (resp.statusCode == 200) return resp.bodyBytes;
      } catch (_) {}
    }
    print('All gateways failed to fetch image: $cid');
    return null;
  }

  // Get IPFS gateway URL
  String getGatewayUrl(String cid) {
    final primary = _gateways.first;
    return '$primary$cid';
  }

  // Pin existing content to IPFS (if using other IPFS nodes)
  Future<bool> pinContent(String cid) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/pinning/pinByHash'),
        headers: _headers,
        body: jsonEncode({
          'hashToPin': cid,
          'pinataMetadata': {
            'name': 'pinned-$cid',
            'keyvalues': {
              'type': 'pinned-content',
              'pinnedAt': DateTime.now().toIso8601String(),
            }
          }
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error pinning content to IPFS: $e');
      return false;
    }
  }

  // Unpin content from IPFS
  Future<bool> unpinContent(String cid) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/pinning/unpin/$cid'),
        headers: _fileHeaders,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error unpinning content from IPFS: $e');
      return false;
    }
  }

  // Get pinned content list
  Future<List<Map<String, dynamic>>?> getPinnedContent() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/data/pinList?status=pinned'),
        headers: _fileHeaders,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(responseData['rows']);
      } else {
        print('Failed to get pinned content: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting pinned content: $e');
      return null;
    }
  }

  // Test IPFS connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/data/testAuthentication'),
        headers: _fileHeaders,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error testing IPFS connection: $e');
      return false;
    }
  }
}