import 'dart:async';

/// Singleton service to route voice transcripts into a single ChatScreen session.
class ChatSessionService {
  ChatSessionService._();
  static final ChatSessionService instance = ChatSessionService._();

  final _incoming = StreamController<String>.broadcast();
  final List<String> _buffer = [];
  bool _isChatOpen = false;
  bool _isOpening = false; // prevents double-push while route is being opened

  Stream<String> get stream => _incoming.stream;
  bool get isChatOpen => _isChatOpen;
  bool get isOpening => _isOpening;

  void setOpen(bool value) {
    _isChatOpen = value;
    if (value && _buffer.isNotEmpty) {
      // Flush buffered messages asynchronously to avoid re-entrancy issues
      final toSend = List<String>.from(_buffer);
      _buffer.clear();
      Future.microtask(() {
        for (final m in toSend) {
          _incoming.add(m);
        }
      });
    }
  }

  void setOpening(bool value) {
    _isOpening = value;
  }

  /// Adds a message to the active chat; buffers if chat is not open yet.
  void sendVoiceMessage(String text) {
    final msg = text.trim();
    if (msg.isEmpty) return;
    if (_isChatOpen) {
      _incoming.add(msg);
    } else {
      _buffer.add(msg);
    }
  }

  /// Forcibly take and clear the buffer (usually not needed if setOpen(true) is used)
  List<String> takeBuffered() {
    final list = List<String>.from(_buffer);
    _buffer.clear();
    return list;
  }

  Future<void> dispose() async {
    await _incoming.close();
  }
}
