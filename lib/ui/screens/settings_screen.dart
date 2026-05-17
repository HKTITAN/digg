import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../background/poller.dart';
import '../../notifications/service.dart';
import '../../storage/cache.dart';
import '../../theme.dart';
import '../widgets/digg_logo.dart';

class SettingsScreen extends StatefulWidget {
  final DiggCache cache;
  const SettingsScreen({super.key, required this.cache});

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
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: DiggColors.green),
            title: const Text('Send a test notification'),
            subtitle: const Text('Verifies notification permission is granted',
                style: TextStyle(color: DiggColors.fgSoft, fontSize: 13)),
            onTap: () async {
              await NotificationService.instance.init();
              await NotificationService.instance.showNewStories(
                newCount: 1, topHeadline: 'Digg notifications are working.',
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sync, color: DiggColors.green),
            title: const Text('Background polling'),
            subtitle: const Text('Checks Digg every 15 minutes for new stories',
                style: TextStyle(color: DiggColors.fgSoft, fontSize: 13)),
            trailing: const Icon(Icons.refresh, color: DiggColors.fgSoft),
            onTap: () async {
              await BackgroundPoller.instance.start();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Background poller re-registered'),
                  backgroundColor: DiggColors.bgSoft,
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.storage_outlined, color: DiggColors.green),
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
          ListTile(
            leading: const Icon(Icons.open_in_browser, color: DiggColors.green),
            title: const Text('Open digg.com'),
            onTap: () => launchUrl(Uri.parse('https://digg.com/ai')),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.code, color: DiggColors.green),
            title: const Text('Source on GitHub'),
            subtitle: const Text('HKTITAN/digg',
                style: TextStyle(color: DiggColors.fgSoft, fontSize: 13)),
            onTap: () => launchUrl(Uri.parse('https://github.com/HKTITAN/digg')),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const DiggWordmark(height: 24, color: DiggColors.fgSoft),
                const SizedBox(height: 6),
                const Text('Personal project. Experimental. Use cautiously.',
                    style: TextStyle(color: DiggColors.fgSoft, fontSize: 12)),
                const SizedBox(height: 12),
                Text('v0.1.0',
                    style: TextStyle(color: DiggColors.fgSoft.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
