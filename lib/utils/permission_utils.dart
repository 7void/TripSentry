import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  /// Requests foreground + background location permission safely
  static Future<bool> requestLocationPermissions() async {
    // Step 1: Request foreground location (fine/coarse)
    final foreground = await Permission.locationWhenInUse.request();

    if (!foreground.isGranted) {
      return false; // ❌ User denied
    }

    // Step 2: Request background location (Android 10+)
    if (await Permission.locationAlways.isDenied ||
        await Permission.locationAlways.isRestricted) {
      final background = await Permission.locationAlways.request();
      if (!background.isGranted) {
        return false; // ❌ User denied background access
      }
    }

    return true; // ✅ Permissions granted
  }
}
