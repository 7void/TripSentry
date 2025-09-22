import 'package:flutter/material.dart';
import '../services/emergency_detection_service.dart';

class EmergencyDetectionTestScreen extends StatefulWidget {
  const EmergencyDetectionTestScreen({super.key});

  @override
  State<EmergencyDetectionTestScreen> createState() =>
      _EmergencyDetectionTestScreenState();
}

class _EmergencyDetectionTestScreenState
    extends State<EmergencyDetectionTestScreen> {
  final EmergencyDetectionService _emergencyService =
      EmergencyDetectionService.instance;
  bool _isListening = false;
  String _lastDetectedPhrase = '';
  List<String> _detectionLog = [];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    final initialized = await _emergencyService.initialize(
      onEmergencyDetected: _onEmergencyDetected,
    );

    if (mounted) {
      setState(() {
        _isListening = initialized;
      });
    }
  }

  void _onEmergencyDetected(String phrase) {
    if (mounted) {
      setState(() {
        _lastDetectedPhrase = phrase;
        _detectionLog.insert(
            0, '${DateTime.now().toString().substring(11, 19)}: "$phrase"');
        if (_detectionLog.length > 10) {
          _detectionLog.removeLast();
        }
      });

      // Show alert dialog instead of navigating to emergency screen
      _showEmergencyAlert(phrase);
    }
  }

  void _showEmergencyAlert(String phrase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 EMERGENCY DETECTED'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detected phrase: "$phrase"'),
            const SizedBox(height: 16),
            const Text(
                'In a real scenario, this would trigger the emergency countdown.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/emergency');
            },
            child: const Text('Go to Emergency Screen'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emergencyService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Detection Test'),
        backgroundColor: Colors.red.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_off,
                          color: _isListening ? Colors.green : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isListening
                              ? 'Listening for emergency phrases...'
                              : 'Not listening',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isListening ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (_lastDetectedPhrase.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last detected: "$_lastDetectedPhrase"',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Emergency Phrases Being Monitored:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: _emergencyService.emergencyPhrases
                        .map((phrase) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber,
                                      size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text('"$phrase"'),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Detection Log:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _detectionLog.isEmpty
                      ? const Center(
                          child: Text(
                            'No emergency phrases detected yet.\nTry saying "help", "I need help", or "I am in danger"',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _detectionLog.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                _detectionLog[index],
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              color: Colors.blue,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 How to test:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Make sure your microphone permission is granted\n'
                      '2. Speak one of the emergency phrases listed above\n'
                      '3. The app will detect it and show an alert\n'
                      '4. In real usage, it would automatically trigger emergency countdown',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
