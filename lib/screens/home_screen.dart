import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkTouristIDStatus();
  }

  Future<void> _checkTouristIDStatus() async {
    final blockchainProvider =
        Provider.of<BlockchainProvider>(context, listen: false);
    await blockchainProvider.refreshTouristRecord();
    await blockchainProvider.checkIfExpired();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourist Safety'),
        actions: [
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
                value: 'clear_data',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear Data', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<BlockchainProvider>(
        builder: (context, blockchainProvider, child) {
          if (blockchainProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _checkTouristIDStatus,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTouristIDSection(context, blockchainProvider),
                  const SizedBox(height: 16),
                  _buildQuickActions(context, blockchainProvider),
                  if (blockchainProvider.hasError) ...[
                    const SizedBox(height: 16),
                    _buildErrorCard(context, blockchainProvider),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTouristIDSection(
      BuildContext context, BlockchainProvider blockchainProvider) {
    if (blockchainProvider.hasActiveTouristID) {
      return _buildActiveTouristIDCard(context, blockchainProvider);
    } else {
      return _buildNoTouristIDCard(context, blockchainProvider);
    }
  }

  Widget _buildActiveTouristIDCard(
      BuildContext context, BlockchainProvider blockchainProvider) {
    final record = blockchainProvider.touristRecord!;
    final isExpired = record.isExpired;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExpired ? Icons.badge_outlined : Icons.badge,
                  color: isExpired ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tourist ID',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 12),
            _buildInfoRow(
                context, 'Token ID:', '#${blockchainProvider.tokenId}'),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              'Valid Until:',
              _formatDate(record.validUntil),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              'Status:',
              record.isActive ? 'Active' : 'Inactive',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/tourist-id-details');
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                if (isExpired)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _deleteExpiredID(context, blockchainProvider),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTouristIDCard(
      BuildContext context, BlockchainProvider blockchainProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.badge_outlined,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tourist ID',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You don\'t have an active Tourist ID yet. Create one to enjoy a secure and verified travel experiences.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/tourist-id-registration');
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Tourist ID'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(
      BuildContext context, BlockchainProvider blockchainProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.qr_code_scanner,
                    'Scan QR',
                    () => _showComingSoon(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.emergency,
                    'Emergency',
                    () => _showComingSoon(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.location_on,
                    'Check-In',
                    () => _showComingSoon(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.my_location,
                    'Geo Location',
                    () => Navigator.of(context).pushNamed('/geo-fencing'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    Icons.map,
                    'Test Map',
                    () => Navigator.of(context).pushNamed('/test-map'), // ✅
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()), // filler
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label,
      VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(
      BuildContext context, BlockchainProvider blockchainProvider) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text(
                  'Error',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              blockchainProvider.errorMessage,
              style: TextStyle(color: Colors.red.shade600),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: blockchainProvider.clearError,
              child: const Text('Dismiss'),
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
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _handleMenuAction(BuildContext context, String action) async {
    final blockchainProvider =
        Provider.of<BlockchainProvider>(context, listen: false);

    switch (action) {
      case 'refresh':
        _checkTouristIDStatus();
        break;
      case 'clear_data':
        _showClearDataDialog(context, blockchainProvider);
        break;
      case 'logout':
        try {
          await FirebaseAuth.instance.signOut();
        } finally {
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        }
        break;
    }
  }

  void _showClearDataDialog(
      BuildContext context, BlockchainProvider blockchainProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Tourist Data'),
        content: const Text(
          'This will permanently delete your tourist data and all associated information. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await blockchainProvider.clearWallet();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/home');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteExpiredID(
      BuildContext context, BlockchainProvider blockchainProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expired Tourist ID'),
        content: const Text(
          'This will permanently delete your expired Tourist ID from the blockchain. '
          'This action cannot be undone.',
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Tourist ID deleted successfully'
                          : 'Failed to delete Tourist ID',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
