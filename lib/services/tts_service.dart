import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    // Basic defaults; adjust as needed
    await _tts.setSpeechRate(Platform.isIOS ? 0.5 : 0.6);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    // Language best-effort; if not supported, plugin keeps default
    try {
      await _tts.setLanguage('en-US');
    } catch (_) {}

    _tts.setStartHandler(() {
      _isSpeaking = true;
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });
    _initialized = true;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInitialized();
    // Stop any ongoing speech before starting new
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
    // Avoid excessively long utterances in a single call
    final chunks = _chunk(text, 400);
    for (final c in chunks) {
      await _tts.speak(c);
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> dispose() async {
    await _tts.stop();
  }

  List<String> _chunk(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final words = text.split(RegExp(r'\s+'));
    final List<String> parts = [];
    final StringBuffer buf = StringBuffer();
    for (final w in words) {
      final next = buf.isEmpty ? w : ' $w';
      if (buf.length + next.length > maxLen) {
        parts.add(buf.toString());
        buf.clear();
        buf.write(w);
      } else {
        buf.write(next);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    return parts;
  }
}
