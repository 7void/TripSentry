// Updated TouristRecord model to match the enhanced smart contract

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
  final String touristAddress; // fetched via ownerOf
  final String issuerInfo;
  final DateTime? issuedAt; // optional (derived from block timestamp if backend supplies)

  TouristRecord({
    required this.touristIdHash,
    required this.metadataCID,
    required this.validUntil,
    required this.touristAddress,
    required this.issuerInfo,
    this.issuedAt,
  });

  bool get isActive => DateTime.now().isBefore(validUntil);
  bool get isValid => isActive; // simplified semantics
  bool get isExpired => !isActive;

  int get daysUntilExpiry {
    if (isExpired) return 0;
    return validUntil.difference(DateTime.now()).inDays;
  }

  // Create from smart contract response
  factory TouristRecord.fromList(List<dynamic> data, {String touristAddress = ''}) {
    // Simplified contract tuple: [touristIdHash, validUntil, metadataCID, issuerInfo]
    return TouristRecord(
      touristIdHash: data[0].toString(),
      validUntil: DateTime.fromMillisecondsSinceEpoch(((data[1] as BigInt).toInt()) * 1000),
      metadataCID: data[2].toString(),
      issuerInfo: data[3].toString(),
      touristAddress: touristAddress,
      issuedAt: null,
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
      if (issuedAt != null) 'issuedAt': issuedAt!.toIso8601String(),
      'issuerInfo': issuerInfo,
    };
  }

  // Create from JSON
  factory TouristRecord.fromJson(Map<String, dynamic> json) {
    return TouristRecord(
      touristIdHash: json['touristIdHash'] ?? '',
      metadataCID: json['metadataCID'] ?? '',
      validUntil: DateTime.parse(json['validUntil']),
      touristAddress: json['touristAddress'] ?? '',
      issuerInfo: json['issuerInfo'] ?? '',
      issuedAt: json['issuedAt'] != null ? DateTime.parse(json['issuedAt']) : null,
    );
  }

  // Copy with method for updates
  TouristRecord copyWith({
    String? touristIdHash,
    String? metadataCID,
    DateTime? validUntil,
    String? touristAddress,
    DateTime? issuedAt,
    String? issuerInfo,
  }) {
    return TouristRecord(
      touristIdHash: touristIdHash ?? this.touristIdHash,
      metadataCID: metadataCID ?? this.metadataCID,
      validUntil: validUntil ?? this.validUntil,
      touristAddress: touristAddress ?? this.touristAddress,
      issuedAt: issuedAt ?? this.issuedAt,
      issuerInfo: issuerInfo ?? this.issuerInfo,
    );
  }

  @override
  String toString() {
    return 'TouristRecord(touristIdHash: $touristIdHash, metadataCID: $metadataCID, validUntil: $validUntil, touristAddress: $touristAddress, issuedAt: $issuedAt, issuerInfo: $issuerInfo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  return other is TouristRecord &&
    other.touristIdHash == touristIdHash &&
    other.metadataCID == metadataCID &&
    other.validUntil == validUntil &&
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
      touristAddress,
      issuedAt,
      issuerInfo,
    );
  }
}
