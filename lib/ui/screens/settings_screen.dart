import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../notifications/service.dart';
import '../../storage/cache.dart';
import '../../sync/sync_manager.dart';
import '../../theme.dart';
import '../widgets/digg_logo.dart';

class SettingsScreen extends StatefulWidget {
  final DiggCache cache;
  final DiggSyncManager sync;
  const SettingsScreen({super.key, required this.cache, required this.sync});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _cacheCount = 0;

  @override
  void initState() {
    super.initState();
    _cacheCount = widget.cache.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _section('Sync'),

          // Sync status — listens to the manager and updates live.
          ValueListenableBuilder<bool>(
            valueListenable: widget.sync.running,
            builder: (_, running, __) => ValueListenableBuilder<SyncResult?>(
              valueListenable: widget.sync.lastResult,
              builder: (_, result, __) => _SyncTile(
                running: running,
                result: result,
                onSync: () => widget.sync.sync(force: true),
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: DiggColors.fgSoft),
            title: const Text('Reset sync index'),
            subtitle: const Text('Clears what we know; next sync will refetch everything',
                style: TextStyle(color: DiggColors.fgSoft, fontSize: 13)),
            onTap: () async {
              await widget.sync.reset();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync index cleared'), backgroundColor: DiggColors.bgSoft),
              );
            },
          ),
          const Divider(height: 1),

          _section('Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: DiggColors.green),
            title: const Text('Send a test notification'),
            subtitle: const Text('Verifies the OS notification channel is working',
                style: TextStyle(color: DiggColors.fgSoft, fontSize: 13)),
            onTap: () async {
              await NotificationService.instance.init();
              await NotificationService.instance.showNewStories(
                newCount: 1,
                topHeadline: 'Digg notifications are working.',
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Test notification fired. Check your tray.'),
                  backgroundColor: DiggColors.bgSoft,
                ),
              );
            },
          ),
          const Divider(height: 1),

          _section('Storage'),
          ListTile(
            leading: const Icon(Icons.storage_outlined, color: DiggColors.fgSoft),
            title: const Text('Cache'),
            subtitle: Text(
              '$_cacheCount entries · kept for 7 days, then evicted',
              style: const TextStyle(color: DiggColors.fgSoft, fontSize: 13),
            ),
            trailing: TextButton(
              onPressed: () async {
                await widget.cache.clear();
                if (!mounted) return;
                setState(() => _cacheCount = widget.cache.size);
              },
              child: const Text('Clear', style: TextStyle(color: DiggColors.sentimentNegative)),
            ),
          ),
          const Divider(height: 1),

          _section('Open'),
          ListTile(
            leading: const Icon(Icons.open_in_browser, color: DiggColors.fgSoft),
            title: const Text('Open digg.com'),
            onTap: () => launchUrl(Uri.parse('https://digg.com/ai')),
          ),
          ListTile(
            leading: const Icon(Icons.code, color: DiggColors.fgSoft),
            title: const Text('Source on GitHub'),
            subtitle: const Text('HKTITAN/digg',
                style: TextStyle(color: DiggColors.fgSoft, fontSize: 13)),
            onTap: () => launchUrl(Uri.parse('https://github.com/HKTITAN/digg')),
          ),

          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                const DiggWordmark(height: 24, color: DiggColors.fgSoft),
                const SizedBox(height: 6),
                const Text('Personal project. Experimental. Use cautiously.',
                    style: TextStyle(color: DiggColors.fgSoft, fontSize: 12)),
                const SizedBox(height: 8),
                Text('v0.1.4',
                    style: TextStyle(color: DiggColors.fgSoft.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: DiggColors.fgSoft,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _SyncTile extends StatelessWidget {
  final bool running;
  final SyncResult? result;
  final Future<void> Function() onSync;
  const _SyncTile({required this.running, required this.result, required this.onSync});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final lastSyncedLabel = r != null ? _ago(r.syncedAt) : 'never';
    final subtitle = r == null
        ? 'Tap to fetch and prefetch the feed'
        : '${r.totalKnown} known · ${r.newSlugs} new · ${r.updatedSlugs} updated · ${r.skippedByRateLimit} skipped · last sync $lastSyncedLabel';

    return ListTile(
      leading: SizedBox(
        width: 24, height: 24,
        child: running
            ? const CircularProgressIndicator(strokeWidth: 2, color: DiggColors.green)
            : const Icon(Icons.sync, color: DiggColors.green),
      ),
      title: Text(running ? 'Syncing…' : 'Sync now'),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: DiggColors.fgSoft, fontSize: 13, height: 1.3),
      ),
      onTap: running ? null : () => onSync(),
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(t.toLocal());
  }
}
