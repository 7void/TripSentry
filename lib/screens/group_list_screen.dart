import 'package:flutter/material.dart';
import '../services/group_service.dart';

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = GroupService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
        actions: [
          IconButton(
            tooltip: 'Scan Group QR',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final res = await Navigator.of(context).pushNamed('/groupInviteScan');
              if (!context.mounted) return;
              if (res is Map && res['joined'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Joined group via QR')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Join by ID',
            icon: const Icon(Icons.login),
            onPressed: () async {
              final controller = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Join Group'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Enter group ID',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final id = controller.text.trim();
                        if (id.isEmpty) return;
                        final joined = await gs.joinGroup(id);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, joined);
                      },
                      child: const Text('Join'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Joined group')), 
                );
              } else if (ok == false && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to join group')), 
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: gs.groupsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data ?? const [];
          if (groups.isEmpty) {
            return const Center(child: Text('No groups yet'));
          }
              return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final g = groups[i];
                  return ListTile(
                title: Text(g['name'] ?? 'Group'),
                subtitle: Text(g['id'] ?? ''),
                    onTap: () {
                      Navigator.of(context).pushNamed('/groupChat', arguments: g['id']);
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'share_qr') {
                          Navigator.of(context).pushNamed(
                            '/groupInviteQr',
                            arguments: {
                              'groupId': g['id'] ?? '',
                              'name': g['name'] ?? 'Group',
                            },
                          );
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'share_qr',
                          child: Text('Share QR'),
                        ),
                      ],
                    ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = TextEditingController();
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Create Group'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Group name'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      final id = await gs.createGroup(name: name);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (id != null && context.mounted) {
                        Navigator.of(context).pushNamed('/groupChat', arguments: id);
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.group_add),
      ),
    );
  }
}


