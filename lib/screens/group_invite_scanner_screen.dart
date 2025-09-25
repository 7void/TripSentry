import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/group_service.dart';

class GroupInviteScannerScreen extends StatefulWidget {
  const GroupInviteScannerScreen({super.key});

  @override
  State<GroupInviteScannerScreen> createState() => _GroupInviteScannerScreenState();
}

class _GroupInviteScannerScreenState extends State<GroupInviteScannerScreen> {
  bool _handled = false;
  final MobileScannerController _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  Future<void> _handlePayload(String raw) async {
    if (_handled) return;
    try {
      final obj = jsonDecode(raw);
      if (obj is! Map) return;
      if (obj['type'] != 'group_invite') return;
      final groupId = (obj['groupId'] ?? '').toString();
      if (groupId.isEmpty) return;
      _handled = true;
      final success = await GroupService.instance.joinGroup(groupId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined group')));
        Navigator.of(context).pop({'joined': true, 'groupId': groupId});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to join group')));
        Navigator.of(context).pop({'joined': false});
      }
    } catch (_) {
      // ignore invalid payloads
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Group QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final b in barcodes) {
                final raw = b.rawValue;
                if (raw != null) {
                  _handlePayload(raw);
                  break;
                }
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Align the QR within the frame to join the group',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _controller.toggleTorch();
          setState(() {});
        },
        child: const Icon(Icons.flash_on),
      ),
    );
  }
}
