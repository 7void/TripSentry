import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kTrackingPrefKey = 'tracking_enabled';

class LocationServiceHelper {
  static const platform = MethodChannel("com.example.touristapp/location");

  static Future<void> startService() async {
    await platform.invokeMethod("startService");
  }

  static Future<void> stopService() async {
    await platform.invokeMethod("stopService");
  }

  /// Only start if user preference indicates tracking enabled (defaults to true when unset)
  static Future<void> startServiceIfAllowed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_kTrackingPrefKey);
      if (enabled == null || enabled) {
        await startService();
      }
    } catch (_) {
      // On any persistence error, be conservative: do NOT auto-start
    }
  }
}
