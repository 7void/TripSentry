import 'package:flutter/material.dart';
import '../services/group_service.dart';

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({super.key});

  void _showJoinByIdDialog(BuildContext context, GroupService gs) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Join Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter group ID',
            filled: true,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              final joined = await gs.joinGroup(id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx, joined);
            },
            icon: const Icon(Icons.login),
            label: const Text('Join'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined group')),
      );
    } else if (ok == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join group')),
      );
    }
  }

  Future<void> _showCreateGroupDialog(BuildContext context, GroupService gs) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Group name',
            filled: true,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
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
            icon: const Icon(Icons.check),
            label: const Text('Create'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = GroupService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        centerTitle: false,
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
            onPressed: () => _showJoinByIdDialog(context, gs),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
            ],
          ),
        ),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: gs.groupsStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final groups = snap.data ?? const [];
            if (groups.isEmpty) {
              return _EmptyGroups(
                onCreate: () => _showCreateGroupDialog(context, gs),
                onScan: () async {
                  final res = await Navigator.of(context).pushNamed('/groupInviteScan');
                  if (!context.mounted) return;
                  if (res is Map && res['joined'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Joined group via QR')),
                    );
                  }
                },
                onJoinById: () => _showJoinByIdDialog(context, gs),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final g = groups[i];
                final String name = (g['name'] ?? 'Group').toString();
                final String id = (g['id'] ?? '').toString();
                return _GroupTile(
                  name: name,
                  id: id,
                  onTap: () => Navigator.of(context).pushNamed('/groupChat', arguments: id),
                  onShareQr: () => Navigator.of(context).pushNamed(
                    '/groupInviteQr',
                    arguments: {'groupId': id, 'name': name},
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: _CreateFab(onPressed: () => _showCreateGroupDialog(context, gs)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _CreateFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _CreateFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.group_add),
      label: const Text('New Group'),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final String name;
  final String id;
  final VoidCallback onTap;
  final VoidCallback onShareQr;
  const _GroupTile({
    required this.name,
    required this.id,
    required this.onTap,
    required this.onShareQr,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'G',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $id',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Share QR',
                icon: const Icon(Icons.qr_code),
                onPressed: onShareQr,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onScan;
  final VoidCallback onJoinById;
  const _EmptyGroups({
    required this.onCreate,
    required this.onScan,
    required this.onJoinById,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
                ),
              ),
              padding: const EdgeInsets.all(22),
              child: Icon(Icons.groups_2, size: 64, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              'No groups yet',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group to start chatting or join one with a QR.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
                OutlinedButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                ),
                TextButton.icon(
                  onPressed: onJoinById,
                  icon: const Icon(Icons.login),
                  label: const Text('Join by ID'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


