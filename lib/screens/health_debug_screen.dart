import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../services/health_connect_service.dart';

class HealthDebugScreen extends StatefulWidget {
  const HealthDebugScreen({super.key});

  @override
  State<HealthDebugScreen> createState() => _HealthDebugScreenState();
}

class _HealthDebugScreenState extends State<HealthDebugScreen> {
  String _log = '';
  List<HealthDataPoint> _latest = [];
  bool _bgAuthorized = false;
  bool _loading = false;

  void _append(String s) => setState(() => _log = (_log + (s.isEmpty ? '' : ('\n' + s))).trim());

  Future<void> _configure() async {
    try {
      setState(() => _loading = true);
      await HealthConnectService.instance.configure();
      _append('Configured');
    } catch (e) {
      _append('Configure error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _requestPermissions() async {
    try {
      setState(() => _loading = true);
      await HealthConnectService.instance.requestPlatformPermissions();
      final ok = await HealthConnectService.instance.requestHealthPermissions();
      _append('Health permissions: $ok');
      _bgAuthorized = await HealthConnectService.instance.isBackgroundReadAuthorized();
      _append('Background read authorized: $_bgAuthorized');
    } catch (e) {
      _append('Permissions error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _readLast24h() async {
    try {
      setState(() => _loading = true);
      final data = await HealthConnectService.instance.readLast24h();
      setState(() => _latest = data);
      _append('Fetched ${data.length} points');
    } catch (e) {
      _append('Read error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _readStepsTotal() async {
    try {
      setState(() => _loading = true);
      final total = await HealthConnectService.instance.getTodayTotalSteps();
      _append('Today total steps: ${total ?? 'null'}');
    } catch (e) {
      _append('Total steps error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _writeSteps() async {
    try {
      setState(() => _loading = true);
      final ok = await HealthConnectService.instance.writeSteps(count: 25);
      _append('Write steps: $ok');
    } catch (e) {
      _append('Write steps error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _writeWorkout() async {
    try {
      setState(() => _loading = true);
      final now = DateTime.now();
      final ok = await HealthConnectService.instance.writeWorkout(
        start: now.subtract(const Duration(minutes: 30)),
        end: now,
        activityType: HealthWorkoutActivityType.WALKING,
        totalDistanceMeters: 2400,
        totalEnergyBurnedKcal: 120,
      );
      _append('Write workout: $ok');
    } catch (e) {
      _append('Write workout error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _configure,
                  child: const Text('Configure'),
                ),
                ElevatedButton(
                  onPressed: _loading ? null : _requestPermissions,
                  child: const Text('Request Permissions'),
                ),
                ElevatedButton(
                  onPressed: _loading ? null : _readLast24h,
                  child: const Text('Read 24h'),
                ),
                ElevatedButton(
                  onPressed: _loading ? null : _readStepsTotal,
                  child: const Text('Total Steps Today'),
                ),
                ElevatedButton(
                  onPressed: _loading ? null : _writeSteps,
                  child: const Text('Write 25 Steps'),
                ),
                ElevatedButton(
                  onPressed: _loading ? null : _writeWorkout,
                  child: const Text('Write Workout'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('BG authorized: $_bgAuthorized'),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black12,
                      child: SingleChildScrollView(
                        child: Text(_log),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ListView.builder(
                      itemCount: _latest.length,
                      itemBuilder: (context, index) {
                        final p = _latest[index];
                        return ListTile(
                          dense: true,
                          title: Text('${p.type} ${p.value.toJson()}'),
                          subtitle: Text('${p.dateFrom} - ${p.dateTo} • ${p.recordingMethod.name}'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
