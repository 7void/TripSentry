import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/blockchain_provider.dart';
import '../models/tourist_record.dart';

class TouristIDDetailsScreen extends StatefulWidget {
  const TouristIDDetailsScreen({super.key});

  @override
  State<TouristIDDetailsScreen> createState() => _TouristIDDetailsScreenState();
}

class _TouristIDDetailsScreenState extends State<TouristIDDetailsScreen> {
  TouristMetadata? _metadata;
  String _qrData = '';
  String? _fsName; // optional Firestore name fallback

  @override
  void initState() {
    super.initState();
    // default QR payload with N/A values
    _qrData = jsonEncode({
      'name': 'N/A',
      'passportNumber': 'N/A',
      'aadharNumber': 'N/A',
      'phoneNumber': 'N/A',
    });
    _loadMetadata();
    _loadQrPayloadFromFirestore();
  }

  Future<void> _loadMetadata() async {
    final blockchainProvider =
        Provider.of<BlockchainProvider>(context, listen: false);
    try {
      final metadata = await blockchainProvider.getMetadataFromIPFS();
      setState(() {
        _metadata = metadata;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load metadata: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadQrPayloadFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));
      final data = doc.data() ?? <String, dynamic>{};
      final name = (data['fullName'] ?? data['name'] ?? user.displayName ?? '').toString();
      final passport = (data['passportNumber'] ?? '').toString();
      final aadhaar = (data['aadharNumber'] ?? '').toString();
      final phone = (data['phoneNumber'] ?? user.phoneNumber ?? '').toString();
      final qrPayload = jsonEncode({
        'name': name.isNotEmpty ? name : 'N/A',
        'passportNumber': passport.isNotEmpty ? passport : 'N/A',
        'aadharNumber': aadhaar.isNotEmpty ? aadhaar : 'N/A',
        'phoneNumber': phone.isNotEmpty ? phone : 'N/A',
      });
      if (!mounted) return;
      setState(() {
        _qrData = qrPayload;
        _fsName = name.isNotEmpty ? name : null;
      });
    } catch (_) {
      // keep default N/A QR on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourist ID'),
      ),
      body: Consumer<BlockchainProvider>(
        builder: (context, blockchainProvider, child) {
          final record = blockchainProvider.touristRecord;

          if (record == null) {
            return const Center(
              child: Text('No Tourist ID found'),
            );
          }

          // Only show the ID card in the body
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildBankStyleIDCard(context, record),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBankStyleIDCard(BuildContext context, TouristRecord record) {
    final theme = Theme.of(context);
  // Prefer Firestore name for faster fetch; fallback to IPFS metadata
  final name = _fsName ?? _metadata?.name ?? '—';
    final expiry = _formatDate(record.validUntil);

    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.grey.shade800, // light grey background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // ensure children respect rounded corners
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Photo placeholder (top-right)
          Positioned(
            top: 16,
            right: 16,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.9),
              child: const Icon(Icons.person, color: Colors.black87),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.badge, color: Colors.white.withOpacity(0.95)),
                        const SizedBox(width: 8),
                        Text(
                          'TOURIST ID',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox.shrink(),
                  ],
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NAME',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white70,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // VALID UNTIL bottom-left
          Positioned(
            left: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VALID UNTIL',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expiry,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // QR for hotel check-in (bottom-right)
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 86,
                gapless: true,
              ),
            ),
          ),
        ],
      ),
    );
  }


  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
