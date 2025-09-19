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
}
