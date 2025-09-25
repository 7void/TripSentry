import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthConnectService {
	HealthConnectService._();
	static final HealthConnectService instance = HealthConnectService._();

	// Global Health instance
	final Health _health = Health();
	bool _configured = false;

	// Supported data types
		static const List<HealthDataType> _readTypes = <HealthDataType>[
		HealthDataType.STEPS,
		HealthDataType.HEART_RATE,
		HealthDataType.BLOOD_GLUCOSE,
		HealthDataType.WORKOUT,
	];

		static const List<HealthDataType> _writeTypes = <HealthDataType>[
			HealthDataType.STEPS,
			HealthDataType.BLOOD_GLUCOSE,
			HealthDataType.WORKOUT,
		];

	Future<void> configure() async {
		if (_configured) return;
		await _health.configure();
		_configured = true;
	}

	Future<bool> requestPlatformPermissions() async {
		// App-level permissions (Activity Recognition, location for workouts route)
		try {
			final activity = await Permission.activityRecognition.request();
			if (!activity.isGranted) return false;
			// Location may be required for outdoor workouts/routes; request when available
			final loc = await Permission.locationWhenInUse.request();
			if (!loc.isGranted) {
				// Not fatal for basic metrics
			}
		} catch (_) {}
		return true;
	}

		Future<bool> requestHealthPermissions({bool withBackground = true}) async {
		await configure();

			// For requestAuthorization, pass all types we want to read/write and specify access per type
			final allTypes = <HealthDataType>{..._readTypes, ..._writeTypes}.toList();
			final permissions = List<HealthDataAccess>.filled(
				allTypes.length,
				HealthDataAccess.READ_WRITE,
				growable: false,
			);

			final ok = await _health.requestAuthorization(allTypes, permissions: permissions);

		if (!ok) return false;

		if (withBackground && defaultTargetPlatform == TargetPlatform.android) {
			try {
				await _health.requestHealthDataInBackgroundAuthorization();
			} catch (_) {}
		}
		return true;
	}

		Future<List<HealthDataPoint>> readLast24h({
			RecordingMethod? method,
		}) async {
		await configure();
		final now = DateTime.now();
		final yesterday = now.subtract(const Duration(hours: 24));

			List<HealthDataPoint> points = [];
			try {
				points = await _health.getHealthDataFromTypes(
					types: _readTypes,
					startTime: yesterday,
					endTime: now,
					recordingMethodsToFilter: method == null ? const [] : <RecordingMethod>[method],
				);
		} on HealthException catch (e) {
			debugPrint('Health read error: $e');
			rethrow;
		}
			points = _health.removeDuplicates(points);
		return points;
	}

	Future<int?> getTodayTotalSteps() async {
		await configure();
		final now = DateTime.now();
		final start = DateTime(now.year, now.month, now.day);
		try {
			final total = await _health.getTotalStepsInInterval(start, now);
			return total;
		} on HealthException catch (e) {
			debugPrint('getTotalStepsInInterval error: $e');
			return null;
		}
	}

		Future<HealthDataPoint?> getByUUID(String uuid, {required HealthDataType type}) async {
		await configure();
		try {
				final point = await _health.getHealthDataByUUID(uuid: uuid, type: type);
				return point;
		} on HealthException catch (e) {
			debugPrint('getByUUID error: $e');
			return null;
		}
	}

		Future<bool> writeSteps({
		required int count,
		DateTime? start,
		DateTime? end,
	}) async {
		await configure();
		final s = start ?? DateTime.now().subtract(const Duration(minutes: 10));
		final e = end ?? DateTime.now();
		try {
				return await _health.writeHealthData(
					value: count.toDouble(),
					type: HealthDataType.STEPS,
					startTime: s,
					endTime: e,
					recordingMethod: RecordingMethod.manual,
				);
		} on HealthException catch (e) {
			debugPrint('writeSteps error: $e');
			return false;
		}
	}

		Future<bool> writeBloodGlucose({
		required double mmolL,
		DateTime? time,
	}) async {
		await configure();
		final t = time ?? DateTime.now();
		try {
				return await _health.writeHealthData(
					value: mmolL,
					type: HealthDataType.BLOOD_GLUCOSE,
					startTime: t,
					endTime: t,
					recordingMethod: RecordingMethod.manual,
				);
		} on HealthException catch (e) {
			debugPrint('writeBloodGlucose error: $e');
			return false;
		}
	}

		Future<bool> writeWorkout({
			required DateTime start,
			required DateTime end,
			required HealthWorkoutActivityType activityType,
			int? totalEnergyBurnedKcal,
			int? totalDistanceMeters,
		}) async {
		await configure();
		try {
				return await _health.writeWorkoutData(
					activityType: activityType,
					start: start,
					end: end,
					totalEnergyBurned: totalEnergyBurnedKcal,
					totalDistance: totalDistanceMeters,
				);
		} on HealthException catch (e) {
			debugPrint('writeWorkout error: $e');
			return false;
		}
	}

	Future<void> syncLatestHeartRate({String? userId}) async {
		final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return;

		try {
			final points = await readLast24h(method: RecordingMethod.automatic);
					final hr = points
					.where((p) => p.type == HealthDataType.HEART_RATE)
					.toList()
				..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
			if (hr.isEmpty) return;
			final latest = hr.first;
			await FirebaseFirestore.instance.collection('users').doc(uid).set({
				'healthdata': {
							'heartRate': (latest.value.toJson()['numeric_value'] ?? latest.value.toJson()['numericValue']),
					'timestamp': latest.dateFrom.toUtc().toIso8601String(),
				}
			}, SetOptions(merge: true));
		} catch (e) {
			debugPrint('syncLatestHeartRate error: $e');
		}
	}

	Future<bool> isBackgroundReadAuthorized() async {
		if (defaultTargetPlatform != TargetPlatform.android) return false;
		try {
			return await _health.isHealthDataInBackgroundAuthorized();
		} catch (_) {
			return false;
		}
	}
}

