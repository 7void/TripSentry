package com.example.touristapp

import android.app.*
import android.content.Intent
import android.location.Location
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions

class LocationService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationRequest: LocationRequest
    private var inUnsafeZone = false // ✅ prevents duplicate notifications

    override fun onCreate() {
        super.onCreate()

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        // Request location every 5 seconds
        locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            10000L
        )
            .setMinUpdateIntervalMillis(8000L)
            .build()

        // ✅ Stop service automatically if user logs out
        FirebaseAuth.getInstance().addAuthStateListener { auth ->
            if (auth.currentUser == null) {
                stopSelf()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(1, createNotification("Tracking active"))

        try {
            // ✅ Catch SecurityException to avoid crash if permission not granted yet
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
            stopSelf() // gracefully stop instead of crash
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }

        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedLocationClient.removeLocationUpdates(locationCallback)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(locationResult: LocationResult) {
            for (location: Location in locationResult.locations) {
                updateFirestore(location)
                checkUnsafeZones(location)
            }
        }
    }

    private fun updateFirestore(location: Location) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val db = FirebaseFirestore.getInstance()

        val data = hashMapOf(
            "lastKnownLocation" to hashMapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "timestamp" to Timestamp.now()
            )
        )

        db.collection("users").document(uid)
            .set(data, SetOptions.merge())
            .addOnSuccessListener {
                // Optional: success logging
            }
            .addOnFailureListener { _ ->
                // Optional: error logging
            }
    }

    private fun checkUnsafeZones(location: Location) {
        // ⚠️ Replace with your own unsafe zone coordinates
        val unsafeLat = 22.5726
        val unsafeLng = 88.3639

        val results = FloatArray(1)
        Location.distanceBetween(
            location.latitude, location.longitude,
            unsafeLat, unsafeLng,
            results
        )

        val inside = results[0] < 200 // within 200 meters
        if (inside && !inUnsafeZone) {
            showNotification("Entered unsafe zone!")
            inUnsafeZone = true
        } else if (!inside && inUnsafeZone) {
            showNotification("Exited unsafe zone")
            inUnsafeZone = false
        }
    }

    private fun createNotification(content: String): Notification {
        val channelId = "location_channel"
        val channel = NotificationChannel(
            channelId,
            "Location Tracking",
            NotificationManager.IMPORTANCE_LOW // ✅ less intrusive
        )
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Tourist Safety")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true) // ✅ prevents swipe-dismiss
            .build()
    }

    private fun showNotification(msg: String) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(2, createNotification(msg))
    }
}
