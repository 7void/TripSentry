import 'package:flutter/services.dart';

class LocationServiceHelper {
  static const platform = MethodChannel("com.example.touristapp/location");

  static Future<void> startService() async {
    await platform.invokeMethod("startService");
  }

  static Future<void> stopService() async {
    await platform.invokeMethod("stopService");
  }
}
