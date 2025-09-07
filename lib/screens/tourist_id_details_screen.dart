import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/blockchain_provider.dart';
import '../models/tourist_record.dart';

class TouristIDDetailsScreen extends StatefulWidget {
  const TouristIDDetailsScreen({super.key});

  @override
  State<TouristIDDetailsScreen> createState() => _TouristIDDetailsScreenState();
}

class _TouristIDDetailsScreenState extends State<TouristIDDetailsScreen> {
  TouristMetadata? _metadata;
  bool _isLoadingMetadata = true;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final blockchainProvider =
        Provider.of<BlockchainProvider>(context, listen: false);
    try {
      final metadata = await blockchainProvider.getMetadataFromIPFS();
      setState(() {
        _metadata = metadata;
        _isLoadingMetadata = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMetadata = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourist ID Details'),
        actions: [
          IconButton(
            onPressed: () => _showQRCode(context),
            icon: const Icon(Icons.qr_code),
            tooltip: 'Show QR Code',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_address',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copy Address'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<BlockchainProvider>(
        builder: (context, blockchainProvider, child) {
          final record = blockchainProvider.touristRecord;

          if (record == null) {
            return const Center(
              child: Text('No Tourist ID found'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await blockchainProvider.refreshTouristRecord();
              await _loadMetadata();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIDCard(context, blockchainProvider, record),
                  const SizedBox(height: 16),
                  _buildBlockchainInfo(context, blockchainProvider, record),
                  const SizedBox(height: 16),
                  if (_isLoadingMetadata)
                    const Center(child: CircularProgressIndicator())
                  else if (_metadata != null)
                    _buildPersonalInfo(context, _metadata!),
                  const SizedBox(height: 16),
                  _buildActionButtons(context, blockchainProvider, record),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIDCard(BuildContext context,
      BlockchainProvider blockchainProvider, TouristRecord record) {
    final isExpired = record.isExpired;

    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isExpired
                ? [Colors.orange.shade400, Colors.orange.shade600]
                : [Colors.blue.shade400, Colors.blue.shade600],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.badge,
                    size: 32,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOURIST ID',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          'Digital Identity Verification',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isExpired ? 'EXPIRED' : 'ACTIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildCardInfoRow('Token ID', '#${blockchainProvider.tokenId}'),
              const SizedBox(height: 8),
              _buildCardInfoRow('Valid Until', _formatDate(record.validUntil)),
              const SizedBox(height: 8),
              _buildCardInfoRow(
                  'Owner', blockchainProvider.shortWalletAddress ?? 'N/A'),
              if (_metadata != null) ...[
                const SizedBox(height: 8),
                _buildCardInfoRow('Name', _metadata!.name),
                const SizedBox(height: 8),
                _buildCardInfoRow('Nationality', _metadata!.nationality),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockchainInfo(BuildContext context,
      BlockchainProvider blockchainProvider, TouristRecord record) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blockchain Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                context, 'Token ID:', '#${blockchainProvider.tokenId}'),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Owner Address:',
                blockchainProvider.walletAddress ?? 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Tourist ID Hash:', record.touristIdHash),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Metadata CID:', record.metadataCID),
            const SizedBox(height: 8),
            _buildInfoRow(
                context, 'Status:', record.isActive ? 'Active' : 'Inactive'),
            const SizedBox(height: 8),
            _buildInfoRow(
                context, 'Valid Until:', _formatDate(record.validUntil)),
            const SizedBox(height: 8),
            _buildInfoRow(
                context,
                'Days Remaining:',
                record.isExpired
                    ? 'Expired'
                    : '${record.validUntil.difference(DateTime.now()).inDays} days'),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfo(BuildContext context, TouristMetadata metadata) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, 'Name:', metadata.name),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Nationality:', metadata.nationality),
            const SizedBox(height: 8),
            _buildInfoRow(
                context, 'Date of Birth:', _formatDate(metadata.dateOfBirth)),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Phone:', metadata.phoneNumber),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Passport:', metadata.passportNumber),
            if (metadata.aadhaarHash.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Aadhaar:', metadata.aadhaarHash),
            ],
            const SizedBox(height: 16),
            Text(
              'Emergency Contact',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Name:', metadata.emergencyContact),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Phone:', metadata.emergencyPhone),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context,
      BlockchainProvider blockchainProvider, TouristRecord record) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showQRCode(context),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Show QR'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(
                        blockchainProvider.walletAddress ?? ''),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Address'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (record.isExpired)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _deleteExpiredID(context, blockchainProvider),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Expired ID'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
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
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
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

  void _showQRCode(BuildContext context) {
    final blockchainProvider =
        Provider.of<BlockchainProvider>(context, listen: false);
    final qrData = {
      'tokenId': blockchainProvider.tokenId,
      'address': blockchainProvider.walletAddress ?? '',
      'touristIdHash': blockchainProvider.touristRecord?.touristIdHash,
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tourist ID QR Code',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData.toString(),
                  version: QrVersions.auto,
                  size: 200.0,
                  gapless: false,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan this QR code to verify your Tourist ID',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    final blockchainProvider =
        Provider.of<BlockchainProvider>(context, listen: false);

    switch (action) {
      case 'refresh':
        blockchainProvider.refreshTouristRecord();
        _loadMetadata();
        break;
      case 'copy_address':
        _copyToClipboard(blockchainProvider.walletAddress ?? '');
        break;
    }
  }

  void _deleteExpiredID(
      BuildContext context, BlockchainProvider blockchainProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expired Tourist ID'),
        content: const Text(
          'This will permanently delete your expired Tourist ID from the blockchain. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await blockchainProvider.deleteExpiredTouristID();
              if (context.mounted) {
                if (success) {
                  Navigator.of(context).pushReplacementNamed('/home');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tourist ID deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Failed to delete Tourist ID: ${blockchainProvider.errorMessage}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
