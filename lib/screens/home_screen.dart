import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_provider.dart';
import '../services/location_service_helper.dart'; // ✅ native service helper
import '../services/location_service.dart'; // control Dart side (non-Android platforms)
import '../utils/permission_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTrackingPrefKey = 'tracking_enabled';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkingPerms = true;
  bool _hasBackground = false;
  bool _hasForeground = false;
  bool _dismissedBanner = false;
  bool _serviceStarted = false; // guard to avoid redundant native starts
  bool _showTrackingChip = false;
  bool _isTracking = false; // current tracking state (active vs paused)
  bool _userWantsTracking = true; // persisted intent
  bool _trackingPrefLoaded =
      false; // ensures we don't auto-start before loading pref

  @override
  void initState() {
    super.initState();
    _checkTouristIDStatus();
    _loadTrackingPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapTrackingPermissions();
      _refreshPermissionState();
    });
  }

  Future<void> _loadTrackingPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_kTrackingPrefKey);
      setState(() {
        _userWantsTracking = stored ?? true; // default: enabled
        _trackingPrefLoaded = true;
        _showTrackingChip = true; // show chip once we know preference
        if (!_userWantsTracking) {
          _isTracking = false; // reflect paused state
        }
      });
      // Attempt start only if user wants tracking (permissions may load slightly later)
      if (_userWantsTracking) {
        _ensureServiceStarted();
      }
    } catch (_) {
      setState(() {
        _trackingPrefLoaded = true;
      });
    }
  }

  Future<void> _saveTrackingPreference(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTrackingPrefKey, enabled);
    } catch (_) {
      // ignore persistence errors silently
    }
  }

  Future<void> _bootstrapTrackingPermissions() async {
    try {
      final got = await PermissionUtils.ensureBackgroundEarly();
      if (!got && mounted) {
        // Offer a rationale with quick access to Settings
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Enable "Allow all the time" for continuous safety tracking.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                // ignore: discarded_futures
                PermissionUtils.openSettingsForBackground();
              },
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      // After early attempt, re-evaluate and possibly start service
      await _refreshPermissionState();
    } catch (_) {
      // Silently ignore – do not block UI
    }
  }

  Future<void> _refreshPermissionState() async {
    setState(() => _checkingPerms = true);
    final fg = await Permission.locationWhenInUse.isGranted;
    final bg = await Permission.locationAlways.isGranted;
    if (mounted) {
      setState(() {
        _hasForeground = fg;
        _hasBackground = bg;
        _checkingPerms = false;
      });
    }
    // Attempt to start tracking if permissions sufficient
    _ensureServiceStarted();
  }

  Future<void> _requestFromBanner() async {
    // Request foreground first if needed
    if (!_hasForeground) {
      final res = await Permission.locationWhenInUse.request();
      if (!res.isGranted) {
        await _refreshPermissionState();
        return;
      }
    }
    // Then request background
    if (!_hasBackground) {
      final res = await Permission.locationAlways.request();
      if (!res.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Background location needed for alerts.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  // ignore: discarded_futures
                  PermissionUtils.openSettingsForBackground();
                },
              ),
            ),
          );
        }
      }
    }
    await _refreshPermissionState();
  }

  void _ensureServiceStarted() {
    if (!_trackingPrefLoaded) return; // wait until preference known
    if (!_userWantsTracking) {
      // user explicitly paused previously; ensure chip visible
      if (!_showTrackingChip) {
        setState(() {
          _showTrackingChip = true;
        });
      }
      return;
    }
    if (_serviceStarted) return;
    if (_hasForeground) {
      _serviceStarted = true;
      // ignore: discarded_futures
      LocationServiceHelper.startService();
      setState(() {
        _showTrackingChip = true;
        _isTracking = true;
      });
    }
  }

  Future<void> _toggleTracking() async {
    if (!_hasForeground) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grant location permission first.')),
      );
      return;
    }
    if (_isTracking) {
      try {
        await LocationServiceHelper.stopService();
        // Pause Dart fallback (no-op on Android due to platform guard)
        await LocationService().pause();
      } catch (_) {}
      if (mounted)
        setState(() {
          _isTracking = false;
          _serviceStarted = false;
          _userWantsTracking = false;
        });
      // ignore: discarded_futures
      _saveTrackingPreference(false);
    } else {
      try {
        await LocationServiceHelper.startService();
        await LocationService().resume();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _showTrackingChip = true;
          _isTracking = true;
          _serviceStarted = true;
          _userWantsTracking = true;
        });
      }
      // ignore: discarded_futures
      _saveTrackingPreference(true);
    }
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
            onRefresh: () async {
              await _refreshPermissionState();
              await _checkTouristIDStatus();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showTrackingChip && _hasForeground)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: Icon(
                            _isTracking
                                ? Icons.gps_fixed
                                : Icons.pause_circle_filled,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            _isTracking
                                ? 'Tracking Active (tap to pause)'
                                : 'Tracking Paused (tap to resume)',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _isTracking
                              ? Colors.green.shade600
                              : Colors.grey.shade600,
                          onPressed: _toggleTracking,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  if (!_dismissedBanner &&
                      !_checkingPerms &&
                      (!_hasForeground || !_hasBackground))
                    _buildPermissionBanner(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed('/chat'),
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    final needsBg = _hasForeground && !_hasBackground;
    return Card(
      color: const Color.fromARGB(255, 24, 24, 24),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: Color.fromARGB(221, 233, 35, 35)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    needsBg
                        ? 'Allow background location to enable continuous safety alerts.'
                        : 'Allow location access to enable safety tracking and alerts.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _dismissedBanner = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _requestFromBanner,
                  icon: const Icon(Icons.security),
                  label:
                      Text(needsBg ? 'Enable Background' : 'Enable Location'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    // ignore: discarded_futures
                    PermissionUtils.openSettingsForBackground();
                  },
                  child: const Text('Settings'),
                ),
              ],
            )
          ],
        ),
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
          await LocationServiceHelper.stopService();
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
          'This will permanently delete your tourist data and all associated information. This action cannot be undone.',
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
