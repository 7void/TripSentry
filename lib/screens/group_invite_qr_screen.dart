import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Shows a QR code that encodes an invite to join a group.
/// Payload format (JSON string):
/// { v: 1, type: 'group_invite', groupId: '<id>', name: '<group name>' }
class GroupInviteQrScreen extends StatelessWidget {
  final String groupId;
  final String groupName;
  const GroupInviteQrScreen({super.key, required this.groupId, required this.groupName});

  @override
  Widget build(BuildContext context) {
    final payload = jsonEncode({
      'v': 1,
      'type': 'group_invite',
      'groupId': groupId,
      'name': groupName,
    });
    final size = MediaQuery.of(context).size;
    final qrSize = (size.width * 0.75).clamp(180.0, 340.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Share Group QR')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Text(
              groupName.isNotEmpty ? groupName : 'Group',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (groupId.isEmpty) ...[
              const SizedBox(height: 24),
              const Text('No group ID provided. Cannot generate invite QR.'),
            ] else Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: qrSize.clamp(180.0, 360.0),
                  gapless: true,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  errorStateBuilder: (c, err) => const SizedBox(
                    width: 200,
                    child: Center(child: Text('Failed to render QR')),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (groupId.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Group ID: ', style: Theme.of(context).textTheme.bodyMedium),
                  SelectableText(groupId, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy group ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: groupId));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group ID copied')));
                    },
                  ),
                ],
              ),
            const SizedBox(height: 8),
            // Debug: show payload preview to verify content being encoded
            SelectableText(
              payload,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            Text(
              'Ask others to scan this QR to join your group.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
