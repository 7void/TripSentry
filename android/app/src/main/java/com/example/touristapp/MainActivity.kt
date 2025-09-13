package com.example.touristapp

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.touristapp/location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val intent = Intent(this, LocationService::class.java)
                    startForegroundService(intent)
                    result.success("Service started")
                }
                "stopService" -> {
                    val intent = Intent(this, LocationService::class.java)
                    stopService(intent)
                    result.success("Service stopped")
                }
                else -> result.notImplemented()
            }
        }
    }
}
