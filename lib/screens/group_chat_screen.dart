import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/group_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({super.key, required this.groupId});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
  final gs = GroupService.instance;
  final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Chat'),
        actions: [
          IconButton(
            tooltip: 'Share Group QR',
            icon: const Icon(Icons.qr_code),
            onPressed: () async {
              final name = '';
              if (!mounted) return;
              Navigator.of(context).pushNamed('/groupInviteQr', arguments: {
                'groupId': widget.groupId,
                'name': name,
              });
            },
          ),
          IconButton(
            tooltip: 'Scan Group QR',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.of(context).pushNamed('/groupInviteScan');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: gs.messagesStream(widget.groupId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!;
                // Auto-scroll to bottom on new data
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final isMine = myUid != null && m['senderUid'] == myUid;
                    final text = (m['text'] ?? '').toString();
                    final sender = (m['senderName'] ?? m['senderUid'] ?? '').toString();
                    return _ChatBubble(
                      isMine: isMine,
                      sender: sender,
                      text: text,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: _InputBar(
              controller: _controller,
              onSend: (text) async {
                final t = text.trim();
                if (t.isEmpty) return;
                await gs.sendMessage(widget.groupId, t);
                if (!mounted) return;
                _controller.clear();
                _scrollToBottom();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isMine;
  final String sender;
  final String text;
  const _ChatBubble({required this.isMine, required this.sender, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isMine ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
    final fg = isMine ? Colors.white : theme.colorScheme.onSurface;
    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 16),
    );
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    sender,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: fg.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: theme.colorScheme.primary,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => onSend(controller.text),
            ),
          ),
        ],
      ),
    );
  }
}


