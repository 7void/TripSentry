import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/tourist_record.dart';

class IPFSService {
  static const String _baseUrl = 'https://api.pinata.cloud';
  static const String _apiKey = 'ae21f2f75c20395ecc52'; 
  static const String _secretApiKey = 'c08fc9a510488ffd1189744126c4fee231a70d977d0beb72fd76cdd835e964ef'; 
  static const String _gatewayUrl = 'https://gateway.pinata.cloud/ipfs/';

  static final IPFSService _instance = IPFSService._internal();
  factory IPFSService() => _instance;
  IPFSService._internal();

  Map<String, String> get _headers => {
        'pinata_api_key': _apiKey,
        'pinata_secret_api_key': _secretApiKey,
        'Content-Type': 'application/json',
      };

  Map<String, String> get _fileHeaders => {
        'pinata_api_key': _apiKey,
        'pinata_secret_api_key': _secretApiKey,
      };

  // Upload JSON metadata to IPFS
  Future<String?> uploadMetadata(TouristMetadata metadata) async {
    try {
      final jsonData = jsonEncode({
        'name': 'Tourist ID - ${metadata.name}',
        'description': 'Digital Tourist ID for ${metadata.nationality} citizen',
        'image': 'ipfs://${metadata.profileImageCID}',
        'attributes': [
          {'trait_type': 'Name', 'value': metadata.name},
          {'trait_type': 'Nationality', 'value': metadata.nationality},
          {'trait_type': 'Phone', 'value': metadata.phoneNumber},
          {'trait_type': 'Emergency Contact', 'value': metadata.emergencyContact},
          {'trait_type': 'Emergency Phone', 'value': metadata.emergencyPhone},
          {'trait_type': 'Date of Birth', 'value': metadata.dateOfBirth.toIso8601String()},
        ],
        'metadata': metadata.toJson(),
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/pinning/pinJSONToIPFS'),
        headers: _headers,
        body: jsonEncode({
          'pinataContent': jsonDecode(jsonData),
          'pinataMetadata': {
            'name': 'tourist-id-${metadata.passportNumber}',
            'keyvalues': {
              'type': 'tourist-metadata',
              'passport': metadata.passportNumber,
              'nationality': metadata.nationality,
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['IpfsHash'];
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
    try {
      final response = await http.get(Uri.parse('$_gatewayUrl$cid'));
      
      if (response.statusCode == 200) {
        return response.body;
      } else {
        print('Failed to get content from IPFS: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting content from IPFS: $e');
      return null;
    }
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
    try {
      final response = await http.get(Uri.parse('$_gatewayUrl$cid'));
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('Failed to get image from IPFS: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting image from IPFS: $e');
      return null;
    }
  }

  // Get IPFS gateway URL
  String getGatewayUrl(String cid) {
    return '$_gatewayUrl$cid';
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