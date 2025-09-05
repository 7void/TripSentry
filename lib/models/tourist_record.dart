import 'dart:typed_data';

class TouristRecord {
  final String touristIdHash;
  final String metadataCID;
  final DateTime validUntil;
  final bool isActive;
  final String touristAddress;

  TouristRecord({
    required this.touristIdHash,
    required this.metadataCID,
    required this.validUntil,
    required this.isActive,
    required this.touristAddress,
  });

  factory TouristRecord.fromList(List<dynamic> data) {
    return TouristRecord(
      touristIdHash: data[0].toString(),
      metadataCID: data[1],
      validUntil: DateTime.fromMillisecondsSinceEpoch(
        (data[2] as BigInt).toInt() * 1000,
      ),
      isActive: data[3],
      touristAddress: data[4].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'touristIdHash': touristIdHash,
      'metadataCID': metadataCID,
      'validUntil': validUntil.millisecondsSinceEpoch,
      'isActive': isActive,
      'touristAddress': touristAddress,
    };
  }

  factory TouristRecord.fromJson(Map<String, dynamic> json) {
    return TouristRecord(
      touristIdHash: json['touristIdHash'],
      metadataCID: json['metadataCID'],
      validUntil: DateTime.fromMillisecondsSinceEpoch(json['validUntil']),
      isActive: json['isActive'],
      touristAddress: json['touristAddress'],
    );
  }

  bool get isExpired => DateTime.now().isAfter(validUntil);
  bool get isValid => isActive && !isExpired;
}

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
    };
  }

  factory TouristMetadata.fromJson(Map<String, dynamic> json) {
    return TouristMetadata(
      name: json['name'],
      passportNumber: json['passportNumber'],
      aadhaarHash: json['aadhaarHash'],
      nationality: json['nationality'],
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
      phoneNumber: json['phoneNumber'],
      emergencyContact: json['emergencyContact'],
      emergencyPhone: json['emergencyPhone'],
      itinerary: List<String>.from(json['itinerary']),
      profileImageCID: json['profileImageCID'],
    );
  }
}

class WalletInfo {
  final String address;
  final String privateKey;
  final Uint8List? publicKey;

  WalletInfo({
    required this.address,
    required this.privateKey,
    this.publicKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'privateKey': privateKey,
      'publicKey': publicKey?.toString(),
    };
  }

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      address: json['address'],
      privateKey: json['privateKey'],
      publicKey: json['publicKey'] != null 
        ? Uint8List.fromList(json['publicKey'].split(',').map((e) => int.parse(e)).toList())
        : null,
    );
  }
}