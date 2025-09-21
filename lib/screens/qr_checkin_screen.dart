import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCheckinScreen extends StatefulWidget {
  final String cid;

  const QrCheckinScreen({super.key, required this.cid});

  @override
  State<QrCheckinScreen> createState() => _QrCheckinScreenState();
}

class _QrCheckinScreenState extends State<QrCheckinScreen> {
  bool _loading = true;
  String? _error;

  // Parsed fields
  String? _name;
  DateTime? _dob;
  String? _passport;
  String? _aadhaar;

  @override
  void initState() {
    super.initState();
    _fetchFromFirestore();
  }

  Future<void> _fetchFromFirestore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not signed in');
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!doc.exists) {
        throw Exception('User profile not found');
      }

      final data = doc.data() ?? <String, dynamic>{};

      // Prefer explicit fields; fallback to FirebaseAuth.displayName
      final name = (data['fullName'] ?? data['name'] ?? user.displayName ?? 'Unknown').toString();

      // Try common keys for date of birth
      DateTime? dob;
      final dobRaw = data['dateOfBirth'] ?? data['dob'];
      if (dobRaw is String) {
        try {
          dob = DateTime.parse(dobRaw);
        } catch (_) {}
      } else if (dobRaw is Timestamp) {
        dob = dobRaw.toDate();
      }

      // Unhashed values from Firestore; compute hashed for display
      final passport = (data['passportNumber'] ?? '').toString();
      final aadhaar = (data['aadharNumber'] ?? '').toString();

      setState(() {
        _name = name;
        _dob = dob;
        _passport = passport.isNotEmpty ? passport : null;
        _aadhaar = aadhaar.isNotEmpty ? aadhaar : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData = 'ipfs://${widget.cid}';
    final size = MediaQuery.of(context).size;
    final qrSize = size.width * 0.7; // large QR on top

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Check-In'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _fetchFromFirestore,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: qrSize.clamp(180.0, 360.0),
                  gapless: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Loading tourist details from IPFS...\nCID: ${widget.cid}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Could not load details',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _fetchFromFirestore,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SelectableText(
                              'CID: ${widget.cid}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tourist Details',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(context, 'Name', _name ?? '-'),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                          context,
                          'DOB',
                          _dob != null
                              ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                              : '-'),
                      const SizedBox(height: 8),
                      _buildInfoRow(context, 'Passport (hashed)',
              _passport ?? '-'),
                      const SizedBox(height: 8),
            _buildInfoRow(context, 'Aadhaar',
              _aadhaar ?? '-'),
                      const SizedBox(height: 12),
                      SelectableText(
                        'CID: ${widget.cid}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
