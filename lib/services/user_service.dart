import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized helpers for linking a blockchain-based TouristID to each user.
///
/// Firestore path: users/{uid}
/// Field: blockchainId (string tokenId or null)
class UserService {
  UserService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  /// Ensure that users/{uid}.blockchainId exists. If missing, create with null.
  static Future<void> ensureBlockchainIdOnLogin() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _fs.collection('users').doc(user.uid);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'blockchainId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }
      final data = snap.data();
      if (data == null || !data.containsKey('blockchainId')) {
        await ref.set({
          'blockchainId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Intentionally swallow to avoid impacting login UX
    }
  }

  /// Update users/{uid}.blockchainId with the minted tokenId.
  static Future<void> updateBlockchainIdAfterMint(int tokenId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final ref = _fs.collection('users').doc(user.uid);
    await ref.set({
      'blockchainId': tokenId.toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch users/{uid}.blockchainId once. Returns null if unset/not found.
  static Future<String?> fetchBlockchainIdOnce() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _fs.collection('users').doc(user.uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    return data?['blockchainId']?.toString();
  }

  /// Subscribe to users/{uid}.blockchainId changes.
  static Stream<String?> blockchainIdStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<String?>.empty();
    }
    return _fs
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((s) => s.data()?['blockchainId']?.toString());
  }

  /// Upsert unhashed identity and emergency contact fields into users/{uid}.
  /// Only fills fields that are missing or empty to avoid overwriting existing data unintentionally.
  /// Fields:
  /// - aadharNumber (string)
  /// - passportNumber (string)
  /// - phoneNumber (string)
  /// - emergencyContactName (string)
  /// - emergencyContactNumber (string)
  static Future<void> upsertUnhashedIdentityFields({
    required String passportNumber,
    String? aadharNumber,
    required String phoneNumber,
    required String emergencyContactName,
    required String emergencyContactNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return; // silently ignore when not signed in
    final ref = _fs.collection('users').doc(user.uid);

    try {
      final snap = await ref.get();
      final data = snap.data() ?? <String, dynamic>{};

      final Map<String, dynamic> toSetIfMissing = {};

      void setIfMissing(String key, String? value) {
        if (value == null || value.trim().isEmpty) return;
        final existing = data[key];
        if (existing == null || (existing is String && existing.trim().isEmpty)) {
          toSetIfMissing[key] = value.trim();
        }
      }

      setIfMissing('passportNumber', passportNumber);
      setIfMissing('aadharNumber', aadharNumber);
      setIfMissing('phoneNumber', phoneNumber);
      setIfMissing('emergencyContactName', emergencyContactName);
      setIfMissing('emergencyContactNumber', emergencyContactNumber);

      if (!snap.exists) {
        // Create doc with provided fields
        await ref.set({
          ...toSetIfMissing,
          'blockchainId': data['blockchainId'] ?? null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (toSetIfMissing.isNotEmpty) {
        await ref.set({
          ...toSetIfMissing,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // Avoid failing the mint flow due to Firestore write issues.
      // You can log this if you have a logger.
    }
  }
}
