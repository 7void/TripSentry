import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String lastWords = "";

  bool get isListening => _isListening;

  /// Initialize the speech engine and set up basic status/error handlers.
  Future<bool> initSpeech() async {
    final ok = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening') {
          _isListening = false;
        }
      },
      onError: (error) {
        _isListening = false;
      },
    );
    return ok;
  }

  /// Start listening and deliver the final recognized text via [onResult].
  /// Partial results are ignored here (but enabled under the hood for better accuracy).
  Future<void> startListening(Function(String) onResult) async {
    if (_isListening) return;
    lastWords = '';
    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        lastWords = result.recognizedWords;
        if (result.finalResult) {
          onResult(lastWords);
        }
      },
      // Use new API to avoid deprecations
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }
}
