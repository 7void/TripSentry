import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  /// Requests both foreground and background in one chained call (legacy usage)
  static Future<bool> requestLocationPermissions() async {
    final foreground = await Permission.locationWhenInUse.request();
    if (!foreground.isGranted) return false;

    if (await Permission.locationAlways.isDenied ||
        await Permission.locationAlways.isRestricted) {
      final background = await Permission.locationAlways.request();
      if (!background.isGranted) return false;
    }
    return true;
  }

  static bool _bootstrapped = false;

  /// Request foreground only if needed
  static Future<bool> requestForegroundIfNeeded() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;
    final res = await Permission.locationWhenInUse.request();
    return res.isGranted;
  }

  /// Request background after a small delay to separate dialogs
  static Future<bool> requestBackgroundWithDelay({
    Duration delay = const Duration(milliseconds: 600),
  }) async {
    final fgOk = await requestForegroundIfNeeded();
    if (!fgOk) return false;

    if (await Permission.locationAlways.isGranted) return true;

    await Future.delayed(delay);

    final bgStatus = await Permission.locationAlways.status;
    if (bgStatus.isGranted) return true;

    if (bgStatus.isDenied || bgStatus.isRestricted) {
      final res = await Permission.locationAlways.request();
      return res.isGranted;
    }
    return await Permission.locationAlways.isGranted;
  }

  /// Full bootstrap invoked after landing on Home
  static Future<bool> ensureBackgroundEarly() async {
    if (_bootstrapped) return await Permission.locationAlways.isGranted;
    _bootstrapped = true;
    return await requestBackgroundWithDelay();
  }

  /// Open settings so user can manually enable background if permanently denied
  static Future<bool> openSettingsForBackground() async {
    return await openAppSettings();
  }
}
