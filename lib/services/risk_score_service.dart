import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hazard_zones.dart';

class RiskScoreUpdate {
  final double riskExposure; // Σ(zone_weight × hours)
  final double safetyScore; // max(0, 100 - riskExposure × factor)
  final String category; // Safe/Caution/Risky/Unsafe
  final DateTime timestamp;
  RiskScoreUpdate({
    required this.riskExposure,
    required this.safetyScore,
    required this.category,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _ActiveSession {
  final String zoneId;
  final HazardSeverity severity;
  final DateTime start;
  _ActiveSession(
      {required this.zoneId, required this.severity, required this.start});
}

class RiskScoreService {
  RiskScoreService._();
  static final RiskScoreService instance = RiskScoreService._();

  // Configurable factor (default 2.0)
  double _factor = 2.0;

  // Persisted totals
  double _riskExposure = 0.0;

  // In-memory active sessions keyed by zoneId
  final Map<String, _ActiveSession> _active = {};

  // Broadcast updates to listeners
  final _controller = StreamController<RiskScoreUpdate>.broadcast();
  Stream<RiskScoreUpdate> get stream => _controller.stream;

  static const _kPrefExposure = 'risk_exposure_total';
  static const _kPrefActive = 'risk_active_sessions';
  static const _kPrefFactor = 'risk_factor';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _riskExposure = prefs.getDouble(_kPrefExposure) ?? 0.0;
    _factor = prefs.getDouble(_kPrefFactor) ?? 2.0;
    // Restore active sessions (best effort)
    final jsonStr = prefs.getString(_kPrefActive);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        data.forEach((zoneId, v) {
          final startMs = (v['startMs'] as num?)?.toInt();
          final sevIndex = (v['sev'] as num?)?.toInt();
          if (startMs != null && sevIndex != null) {
            final sev = HazardSeverity.values[sevIndex];
            _active[zoneId] = _ActiveSession(
              zoneId: zoneId,
              severity: sev,
              start: DateTime.fromMillisecondsSinceEpoch(startMs),
            );
          }
        });
      } catch (_) {}
    }
    _emit();
  }

  Future<void> setFactor(double factor) async {
    _factor = factor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPrefFactor, factor);
    _emit();
  }

  double get factor => _factor;
  double get riskExposure => _riskExposure;

  Future<void> reset() async {
    _riskExposure = 0.0;
    _active.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefExposure);
    await prefs.remove(_kPrefActive);
    _emit();
  }

  // Finalize any active sessions by accumulating exposure up to [endTime] (or now)
  Future<void> finalizeAllActive({DateTime? endTime}) async {
    if (_active.isEmpty) return;
    final end = endTime ?? DateTime.now();
    double added = 0.0;
    _active.removeWhere((zoneId, session) {
      final seconds = end.difference(session.start).inSeconds;
      if (seconds > 0) {
        final hours = seconds / 3600.0;
        added += _weightFor(session.severity) * hours;
      }
      return true; // clear all
    });
    if (added > 0) {
      _riskExposure += added;
      await _persistExposure();
    }
    await _persistActive();
    _emit();
  }

  // Call on geofence ENTER
  Future<void> onEnter(String zoneId, HazardSeverity severity,
      {DateTime? startTime}) async {
    // If already inside, ignore duplicate
    _active.putIfAbsent(
        zoneId,
        () => _ActiveSession(
              zoneId: zoneId,
              severity: severity,
              start: startTime ?? DateTime.now(),
            ));
    await _persistActive();
    _emit();
  }

  // Call on geofence EXIT
  Future<void> onExit(String zoneId, HazardSeverity severity,
      {DateTime? endTime}) async {
    final session = _active.remove(zoneId);
    if (session != null) {
      final end = endTime ?? DateTime.now();
      final seconds = end.difference(session.start).inSeconds;
      if (seconds > 0) {
        final hours = seconds / 3600.0;
        _riskExposure += _weightFor(session.severity) * hours;
        await _persistExposure();
      }
      await _persistActive();
      _emit();
    }
  }

  int _weightFor(HazardSeverity s) {
    switch (s) {
      case HazardSeverity.mild:
        return 100;
      case HazardSeverity.moderate:
        return 500;
      case HazardSeverity.severe:
        return 1000;
    }
  }

  Map<String, dynamic> snapshot() {
    final score = _computeSafetyScore(_riskExposure, _factor);
    return {
      'riskExposure': _riskExposure,
      'safetyScore': score.item1,
      'category': score.item2,
      'factor': _factor,
      'activeCount': _active.length,
    };
  }

  // Returns (score, category)
  _Pair _computeSafetyScore(double exposure, double factor) => _Pair(
        (exposure * factor) >= 100.0 ? 0.0 : (100.0 - (exposure * factor)),
        _categoryFor(
            (exposure * factor) >= 100.0 ? 0.0 : (100.0 - (exposure * factor))),
      );

  String _categoryFor(double score) {
    if (score >= 80) return 'Safe';
    if (score >= 60) return 'Caution';
    if (score >= 40) return 'Risky';
    return 'Unsafe';
  }

  void _emit() {
    final pair = _computeSafetyScore(_riskExposure, _factor);
    _controller.add(RiskScoreUpdate(
      riskExposure: _riskExposure,
      safetyScore: pair.item1,
      category: pair.item2,
    ));
  }

  Future<void> _persistExposure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPrefExposure, _riskExposure);
  }

  Future<void> _persistActive() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    _active.forEach((key, s) {
      map[key] = {
        'sev': s.severity.index,
        'startMs': s.start.millisecondsSinceEpoch,
      };
    });
    await prefs.setString(_kPrefActive, jsonEncode(map));
  }
}

class _Pair {
  final double item1;
  final String item2;
  _Pair(this.item1, this.item2);
}
