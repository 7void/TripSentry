import 'dart:async';
import 'package:flutter/services.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import '../secrets.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Voice assistant high-level events exposed to UI
enum VoiceAssistantEventType {
  ready,
  wakeListening,
  wakeDetected,
  sttListening,
  partialResult,
  finalResult,
  error,
  resumedWake,
  disposed,
  debug,
}

class VoiceAssistantEvent {
  final VoiceAssistantEventType type;
  final String? data;
  final DateTime timestamp;
  VoiceAssistantEvent(this.type, {this.data}) : timestamp = DateTime.now();
  @override
  String toString() =>
      'VoiceAssistantEvent(type: $type, data: $data, ts: $timestamp)';
}

class VoiceAssistantService {
  PorcupineManager? _porcupineManager;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _wakeWordActive = false;
  bool _initialized = false;
  bool _autoStartDone = false;
  double _sensitivity = 0.9; // adjustable
  bool _simulateMode = false; // if true, we bypass wake engine for debugging

  final _controller = StreamController<VoiceAssistantEvent>.broadcast();
  Stream<VoiceAssistantEvent> get events => _controller.stream;

  VoiceAssistantService() {
    _speech = stt.SpeechToText();
  }

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Toggle simulation mode (bypass Porcupine). In simulate mode, a manual call to simulateWake() starts STT.
  Future<void> toggleSimulation() async {
    _simulateMode = !_simulateMode;
    _emit(
        VoiceAssistantEventType.debug,
        _simulateMode
            ? 'Simulation mode ON (manual wake)'
            : 'Simulation mode OFF');
    await reinitialize();
  }

  /// Manually simulate a wake word when in simulation mode
  void simulateWake() {
    if (_simulateMode) {
      _emit(VoiceAssistantEventType.wakeDetected, 'SIMULATED');
      _startListening();
    } else {
      _emit(VoiceAssistantEventType.debug, 'Simulation mode is OFF');
    }
  }

  Future<void> setSensitivity(double value) async {
    _sensitivity = value.clamp(0.0, 1.0);
    _emit(VoiceAssistantEventType.debug, 'Sensitivity set to $_sensitivity');
    await reinitialize();
  }

  Future<void> reinitialize() async {
    if (_wakeWordActive) {
      await _porcupineManager?.stop();
      _wakeWordActive = false;
    }
    _initialized = false;
    await initWakeWord(autoStart: true, force: true);
  }

  /// Initialize wake word detection (idempotent unless force=true)
  Future<void> initWakeWord({bool autoStart = true, bool force = false}) async {
    if (_initialized && !force) return; // prevent double init
    if (_simulateMode) {
      _initialized = true;
      _emit(VoiceAssistantEventType.ready, 'Simulation ready');
      _emit(VoiceAssistantEventType.wakeListening, 'Simulated: tap simulate');
      return;
    }
    try {
      final exists = await _assetExists('assets/wakewords/hey_sentry.ppn');
      if (!exists) {
        _emit(VoiceAssistantEventType.error,
            'Keyword asset missing: assets/wakewords/hey_sentry.ppn');
        _emit(VoiceAssistantEventType.debug,
            'Enable simulation to test pipeline.');
        return;
      }
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        PICOVOICE_ACCESS_KEY,
        ['assets/wakewords/hey_sentry.ppn'],
        _wakeWordCallback,
        sensitivities: [_sensitivity],
      );
      await _porcupineManager?.start();
      _wakeWordActive = true;
      _initialized = true;
      _emit(VoiceAssistantEventType.ready, 'Wake word engine ready');
      _emit(VoiceAssistantEventType.wakeListening,
          'Listening for Hey Sentry (sens=${_sensitivity.toStringAsFixed(2)})');
      if (autoStart && !_autoStartDone) {
        _autoStartDone = true;
      }
    } catch (e) {
      final msg = e.toString();
      String hint = '';
      if (msg.contains('activation') && msg.contains('refused')) {
        hint = 'Invalid / revoked access key or wrong bundle ID.';
      } else if (msg.contains('throttl')) {
        hint = 'Too many activations recently. Retry later.';
      } else if (msg.contains('limit')) {
        hint = 'Device limit reached for key.';
      }
      _emit(VoiceAssistantEventType.error,
          'Init failed: $msg${hint.isNotEmpty ? '\n$hint' : ''}');
    }
  }

  /// Called when wake word is detected
  void _wakeWordCallback(int keywordIndex) async {
    _emit(VoiceAssistantEventType.wakeDetected, 'Hey Sentry');
    await _porcupineManager?.stop();
    _wakeWordActive = false;
    _startListening();
  }

  /// Start capturing user speech
  void _startListening() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening') {
          _finishListening(restartWakeWord: true);
        }
      },
      onError: (error) {
        _emit(VoiceAssistantEventType.error, 'Speech error: $error');
        _finishListening(restartWakeWord: true);
      },
    );
    if (!available) {
      _emit(VoiceAssistantEventType.error, 'Speech recognition not available');
      _restartWakeWordSafely();
      return;
    }
    _isListening = true;
    _emit(VoiceAssistantEventType.sttListening, null);
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _emit(VoiceAssistantEventType.finalResult, result.recognizedWords);
          _finishListening(restartWakeWord: true);
        } else if (result.recognizedWords.isNotEmpty) {
          _emit(VoiceAssistantEventType.partialResult, result.recognizedWords);
        }
      },
      listenMode: stt.ListenMode.confirmation,
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  /// Stop speech listening
  void stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Stop wake word detection
  Future<void> stopWakeWord() async {
    await _porcupineManager?.stop();
    _wakeWordActive = false;
  }

  void _finishListening({bool restartWakeWord = false}) async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
    if (restartWakeWord) {
      _restartWakeWordSafely();
    }
  }

  void _restartWakeWordSafely() async {
    if (_simulateMode) return;
    if (_porcupineManager != null && !_wakeWordActive) {
      try {
        await _porcupineManager?.start();
        _wakeWordActive = true;
        // Resume event for debug history
        _emit(
            VoiceAssistantEventType.resumedWake, 'Wake word listening resumed');
        // Also emit the canonical listening state so UI shows "listening" again
        _emit(
          VoiceAssistantEventType.wakeListening,
          'Listening for Hey Sentry (sens=${_sensitivity.toStringAsFixed(2)})',
        );
      } catch (e) {
        _emit(VoiceAssistantEventType.error, 'Failed to restart wake word: $e');
      }
    }
  }

  Future<void> dispose() async {
    if (_isListening) {
      await _speech.stop();
    }
    if (_wakeWordActive) {
      await _porcupineManager?.stop();
    }
    await _controller.close();
    _porcupineManager = null;
    _emit(VoiceAssistantEventType.disposed, null);
  }

  void _emit(VoiceAssistantEventType type, String? data) {
    if (!_controller.isClosed) {
      _controller.add(VoiceAssistantEvent(type, data: data));
    }
  }
}
