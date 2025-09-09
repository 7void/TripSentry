// Updated TouristRecord model to match the enhanced smart contract
import 'package:web3dart/web3dart.dart';

// Tourist metadata class
class TouristMetadata {
  final String name;
  final String passportNumber;
  final String aadhaarHash;
  final String nationality;
  final DateTime dateOfBirth;
  final String phoneNumber;
  final String emergencyContact;
  final String emergencyPhone;
  final List<String> itinerary;
  final String profileImageCID;
  final DateTime issuedAt;

  TouristMetadata({
    required this.name,
    required this.passportNumber,
    required this.aadhaarHash,
    required this.nationality,
    required this.dateOfBirth,
    required this.phoneNumber,
    required this.emergencyContact,
    required this.emergencyPhone,
    required this.itinerary,
    required this.profileImageCID,
    required this.issuedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'passportNumber': passportNumber,
      'aadhaarHash': aadhaarHash,
      'nationality': nationality,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'phoneNumber': phoneNumber,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'itinerary': itinerary,
      'profileImageCID': profileImageCID,
      'issuedAt': issuedAt.toIso8601String(),
    };
  }

  factory TouristMetadata.fromJson(Map<String, dynamic> json) {
    return TouristMetadata(
      name: json['name'] ?? '',
      passportNumber: json['passportNumber'] ?? '',
      aadhaarHash: json['aadhaarHash'] ?? '',
      nationality: json['nationality'] ?? '',
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
      phoneNumber: json['phoneNumber'] ?? '',
      emergencyContact: json['emergencyContact'] ?? '',
      emergencyPhone: json['emergencyPhone'] ?? '',
      itinerary: List<String>.from(json['itinerary'] ?? []),
      profileImageCID: json['profileImageCID'] ?? '',
      issuedAt: DateTime.parse(json['issuedAt']),
    );
  }
}

class TouristRecord {
  final String touristIdHash;
  final String metadataCID;
  final DateTime validUntil;
  final bool isActive;
  final String touristAddress;
  final DateTime issuedAt; // New field
  final String issuerInfo; // New field

  TouristRecord({
    required this.touristIdHash,
    required this.metadataCID,
    required this.validUntil,
    required this.isActive,
    required this.touristAddress,
    required this.issuedAt,
    required this.issuerInfo,
  });

  bool get isValid => isActive && DateTime.now().isBefore(validUntil);
  bool get isExpired => DateTime.now().isAfter(validUntil);

  int get daysUntilExpiry {
    if (isExpired) return 0;
    return validUntil.difference(DateTime.now()).inDays;
  }

  // Create from smart contract response
  factory TouristRecord.fromList(List<dynamic> data) {
    return TouristRecord(
      touristIdHash: data[0].toString(),
      metadataCID: data[1].toString(),
      validUntil: DateTime.fromMillisecondsSinceEpoch(
        (data[2] as BigInt).toInt() *
            1000, // Convert from seconds to milliseconds
      ),
      isActive: data[3] as bool,
      touristAddress: data[4] is EthereumAddress
          ? (data[4] as EthereumAddress).hex
          : data[4].toString(),
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        (data[5] as BigInt).toInt() *
            1000, // Convert from seconds to milliseconds
      ),
      issuerInfo: data[6].toString(),
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'touristIdHash': touristIdHash,
      'metadataCID': metadataCID,
      'validUntil': validUntil.toIso8601String(),
      'isActive': isActive,
      'touristAddress': touristAddress,
      'issuedAt': issuedAt.toIso8601String(),
      'issuerInfo': issuerInfo,
    };
  }

  // Create from JSON
  factory TouristRecord.fromJson(Map<String, dynamic> json) {
    return TouristRecord(
      touristIdHash: json['touristIdHash'] ?? '',
      metadataCID: json['metadataCID'] ?? '',
      validUntil: DateTime.parse(json['validUntil']),
      isActive: json['isActive'] ?? false,
      touristAddress: json['touristAddress'] ?? '',
      issuedAt: DateTime.parse(json['issuedAt']),
      issuerInfo: json['issuerInfo'] ?? '',
    );
  }

  // Copy with method for updates
  TouristRecord copyWith({
    String? touristIdHash,
    String? metadataCID,
    DateTime? validUntil,
    bool? isActive,
    String? touristAddress,
    DateTime? issuedAt,
    String? issuerInfo,
  }) {
    return TouristRecord(
      touristIdHash: touristIdHash ?? this.touristIdHash,
      metadataCID: metadataCID ?? this.metadataCID,
      validUntil: validUntil ?? this.validUntil,
      isActive: isActive ?? this.isActive,
      touristAddress: touristAddress ?? this.touristAddress,
      issuedAt: issuedAt ?? this.issuedAt,
      issuerInfo: issuerInfo ?? this.issuerInfo,
    );
  }

  @override
  String toString() {
    return 'TouristRecord(touristIdHash: $touristIdHash, metadataCID: $metadataCID, validUntil: $validUntil, isActive: $isActive, touristAddress: $touristAddress, issuedAt: $issuedAt, issuerInfo: $issuerInfo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TouristRecord &&
        other.touristIdHash == touristIdHash &&
        other.metadataCID == metadataCID &&
        other.validUntil == validUntil &&
        other.isActive == isActive &&
        other.touristAddress == touristAddress &&
        other.issuedAt == issuedAt &&
        other.issuerInfo == issuerInfo;
  }

  @override
  int get hashCode {
    return Object.hash(
      touristIdHash,
      metadataCID,
      validUntil,
      isActive,
      touristAddress,
      issuedAt,
      issuerInfo,
    );
  }
}
