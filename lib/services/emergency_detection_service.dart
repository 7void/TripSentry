import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Emergency detection service that continuously monitors for emergency phrases
/// and triggers emergency response when detected
class EmergencyDetectionService {
  static final EmergencyDetectionService _instance =
      EmergencyDetectionService._internal();
  static EmergencyDetectionService get instance => _instance;
  EmergencyDetectionService._internal();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isInitialized = false;
  Timer? _restartTimer;

  // Emergency phrases to detect (case insensitive)
  final List<String> _emergencyPhrases = [
    'i am in danger',
    'i need help',
    'help me',
    'emergency',
    'call for help',
    'help',
    'sos',
    'danger',
    'attack',
    'threatened',
    'scared',
    'unsafe',
  ];

  // Callback to trigger when emergency phrase is detected
  Function(String detectedPhrase)? _onEmergencyDetected;

  /// Initialize the emergency detection service
  Future<bool> initialize({Function(String)? onEmergencyDetected}) async {
    if (_isInitialized) return true;

    _onEmergencyDetected = onEmergencyDetected;
    _speech = stt.SpeechToText();

    final available = await _speech.initialize(
      onStatus: _onStatusChange,
      onError: _onError,
    );

    if (available) {
      _isInitialized = true;
      await _startContinuousListening();
      return true;
    }

    return false;
  }

  /// Start continuous listening for emergency phrases
  Future<void> _startContinuousListening() async {
    if (!_isInitialized || _isListening) return;

    try {
      _isListening = true;
      await _speech.listen(
        onResult: _onSpeechResult,
        listenMode: stt.ListenMode.confirmation,
        pauseFor: const Duration(seconds: 2), // Short pause to restart quickly
        partialResults: true,
        listenFor: const Duration(minutes: 10), // Listen for extended periods
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('EmergencyDetection: Error starting listening: $e');
      _scheduleRestart();
    }
  }

  /// Handle speech recognition results
  void _onSpeechResult(result) {
    final recognizedText = result.recognizedWords.toLowerCase().trim();

    if (recognizedText.isNotEmpty) {
      debugPrint('EmergencyDetection: Heard: "$recognizedText"');

      // Check if any emergency phrase is detected
      for (final phrase in _emergencyPhrases) {
        if (recognizedText.contains(phrase)) {
          debugPrint(
              'EmergencyDetection: EMERGENCY PHRASE DETECTED: "$phrase"');
          _triggerEmergency(phrase);
          return;
        }
      }
    }
  }

  /// Handle speech recognition status changes
  void _onStatusChange(String status) {
    debugPrint('EmergencyDetection: Status changed to: $status');

    if (status == 'notListening' || status == 'done') {
      _isListening = false;
      // Restart listening after a short delay
      _scheduleRestart();
    }
  }

  /// Handle speech recognition errors
  void _onError(dynamic error) {
    debugPrint('EmergencyDetection: Error: $error');
    _isListening = false;
    _scheduleRestart();
  }

  /// Schedule a restart of the listening process
  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () {
      if (_isInitialized && !_isListening) {
        _startContinuousListening();
      }
    });
  }

  /// Trigger emergency response
  void _triggerEmergency(String detectedPhrase) {
    debugPrint(
        'EmergencyDetection: Triggering emergency for phrase: "$detectedPhrase"');
    _onEmergencyDetected?.call(detectedPhrase);
  }

  /// Stop the emergency detection service
  Future<void> stop() async {
    _isListening = false;
    _restartTimer?.cancel();

    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
    _onEmergencyDetected = null;
  }

  /// Check if the service is currently listening
  bool get isListening => _isListening;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get the list of emergency phrases being monitored
  List<String> get emergencyPhrases => List.unmodifiable(_emergencyPhrases);

  /// Add a custom emergency phrase
  void addEmergencyPhrase(String phrase) {
    if (!_emergencyPhrases.contains(phrase.toLowerCase())) {
      _emergencyPhrases.add(phrase.toLowerCase());
    }
  }

  /// Remove an emergency phrase
  void removeEmergencyPhrase(String phrase) {
    _emergencyPhrases.remove(phrase.toLowerCase());
  }
}
