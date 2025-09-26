import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_provider.dart';
import '../services/location_service_helper.dart'; // ✅ native service helper
import '../services/location_service.dart'; // control Dart side (non-Android platforms)
import '../utils/permission_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_checkin_screen.dart';
import '../l10n/app_localizations.dart';
// locale switcher and old menu removed in redesign
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../services/hazard_zones.dart';

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

  // Center for the non-interactive map preview
  LatLng? _previewCenter;

  @override
  void initState() {
    super.initState();
    _checkTouristIDStatus();
    _loadTrackingPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapTrackingPermissions();
      _refreshPermissionState();
      // Try to fetch a quick current location for the preview
      // ignore: discarded_futures
      _updatePreviewToCurrent();
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
            content: Text(
              AppLocalizations.of(context).snackEnableBackground,
            ),
            action: SnackBarAction(
              label: AppLocalizations.of(context).settings,
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
    // Update preview center once we have permission
    if (fg) {
      // ignore: discarded_futures
      _updatePreviewToCurrent();
    }
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
              content: Text(AppLocalizations.of(context).snackBgNeeded),
              action: SnackBarAction(
                label: AppLocalizations.of(context).settings,
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

  Future<void> _updatePreviewToCurrent() async {
    try {
      if (!_hasForeground) return;
      if (!await geo.Geolocator.isLocationServiceEnabled()) return;
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.low,
      );
      if (!mounted) return;
      setState(() {
        _previewCenter = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {
      // ignore failures; fallback center will be used
    }
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
        SnackBar(
          content:
              Text(AppLocalizations.of(context).snackGrantLocationFirst),
        ),
      );
      return;
    }
    if (_isTracking) {
      try {
        await LocationServiceHelper.stopService();
        // Pause Dart fallback (no-op on Android due to platform guard)
        await LocationService().pause();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isTracking = false;
          _serviceStarted = false;
          _userWantsTracking = false;
        });
      }
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
        title: Text(AppLocalizations.of(context).appNameShort),
        actions: [
          // Notification bell (placeholder)
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          // Profile button -> View ID (or prompt to create)
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: AppLocalizations.of(context).viewId,
              onPressed: () {
                final bp = Provider.of<BlockchainProvider>(ctx, listen: false);
                if (bp.hasActiveTouristID) {
                  Navigator.of(ctx).pushNamed('/tourist-id-details');
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Create a Tourist ID first')),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 4),
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
                  // Tracking chip (back to original position, above map)
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
                                ? AppLocalizations.of(context).trackingActive
                                : AppLocalizations.of(context).trackingPaused,
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
                  // Map preview
                  _buildMapPreview(context),
                  const SizedBox(height: 12),
                  if (!_dismissedBanner &&
                      !_checkingPerms &&
                      (!_hasForeground || !_hasBackground))
                    _buildPermissionBanner(),
                  // Tourist ID section card
                  _buildTouristIDSection(context, blockchainProvider),
                  const SizedBox(height: 16),
                  // QR + SOS buttons row
                  _buildQrAndSosRow(context, blockchainProvider),
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
      // Bottom navigation (Home, Groups, Chat)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (idx) {
          if (idx == 1) {
            Navigator.of(context).pushNamed('/groups');
          } else if (idx == 2) {
            Navigator.of(context).pushNamed('/chat');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
        ],
      ),
    );
  }

  // Map preview widget matching the mid-card look; tap to open full map
  Widget _buildMapPreview(BuildContext context) {
    final previewPos = _previewCenter ??
        const LatLng(40.6602, -73.9690); // fallback: Prospect Park area
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          // Non-interactive map for preview
          SizedBox(
            height: 280,
            width: double.infinity,
            child: IgnorePointer(
              child: GoogleMap(
                key: ValueKey(
                  'preview-${previewPos.latitude.toStringAsFixed(5)},${previewPos.longitude.toStringAsFixed(5)}',
                ),
                initialCameraPosition:
                    CameraPosition(target: previewPos, zoom: 13.5),
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                rotateGesturesEnabled: false,
                scrollGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomGesturesEnabled: false,
                markers: {
                  Marker(
                    markerId: const MarkerId('preview'),
                    position: previewPos,
                  )
                },
                circles: _previewCircles(),
              ),
            ),
          ),
          // Full overlay to capture taps (platform view safe)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pushNamed('/geo-fencing'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<Circle> _previewCircles() {
    final Set<Circle> circles = {};
    for (final hz in hazardZones) {
      Color color;
      switch (hz.severity) {
        case HazardSeverity.mild:
          color = Colors.yellow;
          break;
        case HazardSeverity.moderate:
          color = Colors.orange;
          break;
        case HazardSeverity.severe:
          color = Colors.red;
          break;
      }
      circles.add(
        Circle(
          circleId: CircleId('preview_${hz.id}'),
          center: hz.center,
          radius: hz.radiusMeters.toDouble(),
          fillColor: color.withOpacity(0.25),
          strokeColor: color,
          strokeWidth: 2,
        ),
      );
    }
    return circles;
  }

  // Row with QR Check-In and SOS buttons matching pill design
  Widget _buildQrAndSosRow(
      BuildContext context, BlockchainProvider blockchainProvider) {
    return Row(
      children: [
        Expanded(
          child: _pillButton(
            context,
            icon: Icons.qr_code_scanner,
            label: AppLocalizations.of(context).qrCheckIn,
            background: Theme.of(context).colorScheme.surfaceVariant,
            foreground: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: () {
              final record = blockchainProvider.touristRecord;
              final cid = record?.metadataCID;
              if (cid == null || cid.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        AppLocalizations.of(context).snackNoMetadata),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QrCheckinScreen(cid: cid),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pillButton(
            context,
            icon: null,
            label: 'SOS',
            background: Colors.red.shade600,
            foreground: Colors.white,
            onPressed: () => Navigator.of(context).pushNamed('/emergency'),
          ),
        ),
      ],
    );
  }

  Widget _pillButton(BuildContext context,
    {IconData? icon,
      required String label,
      required Color background,
      required Color foreground,
      required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon),
            const SizedBox(width: 8),
          ],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
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
                const Icon(Icons.location_on,
                    color: Color.fromARGB(221, 233, 35, 35)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
          needsBg
            ? AppLocalizations.of(context).permissionBannerNeedBg
            : AppLocalizations.of(context).permissionBannerNeedFg,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).dismiss,
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
          label: Text(needsBg
            ? AppLocalizations.of(context).permissionEnableBg
            : AppLocalizations.of(context).permissionEnableFg),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    // ignore: discarded_futures
                    PermissionUtils.openSettingsForBackground();
                  },
                  child: Text(AppLocalizations.of(context).settings),
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
                  AppLocalizations.of(context).touristId,
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
                    isExpired
                        ? AppLocalizations.of(context).expired
                        : AppLocalizations.of(context).active_caps,
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
        context, AppLocalizations.of(context).tokenId, '#${blockchainProvider.tokenId}'),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              AppLocalizations.of(context).validUntil,
              _formatDate(record.validUntil),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              AppLocalizations.of(context).status,
              record.isActive ? AppLocalizations.of(context).active : AppLocalizations.of(context).inactive,
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
                    label: Text(AppLocalizations.of(context).viewId),
                  ),
                ),
                const SizedBox(width: 12),
                if (isExpired)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _deleteExpiredID(context, blockchainProvider),
                      icon: const Icon(Icons.delete),
                      label: Text(AppLocalizations.of(context).delete),
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
                  AppLocalizations.of(context).touristId,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).noTouristIdBody,
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
                label: Text(AppLocalizations.of(context).createTouristId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Legacy quick actions removed in redesign

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
                  AppLocalizations.of(context).error,
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
              child: Text(AppLocalizations.of(context).dismiss),
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

  // Legacy menu actions removed in redesign

  // Clear data dialog was used by old menu; removed in redesign

  void _deleteExpiredID(
      BuildContext context, BlockchainProvider blockchainProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
  title: Text(AppLocalizations.of(context).deleteExpiredTitle),
  content: Text(AppLocalizations.of(context).deleteExpiredBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await blockchainProvider.deleteExpiredTouristID();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
        content: Text(success
      ? AppLocalizations.of(context).deletedSuccessfully
      : AppLocalizations.of(context).deleteFailed),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
  }

  // Coming soon snackbar helper removed in redesign

  // Language switcher removed from AppBar in redesign
}
