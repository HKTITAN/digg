import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../widgets/digg_logo.dart';
import '../widgets/story_card.dart';
import 'story_screen.dart';

class HomeScreen extends StatefulWidget {
  final DiggClient client;
  const HomeScreen({super.key, required this.client});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Story> _stories = const [];
  TrendingStatus? _status;
  bool _loading = true;
  bool _fromCache = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = _stories.isEmpty);
    try {
      final r = await widget.client.getFeed(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        _stories = r.stories;
        _status = r.status;
        _fromCache = r.fromCache;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const DiggWordmark(height: 20),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: DiggColors.fg),
            onPressed: () => _load(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DiggColors.green,
        onRefresh: () => _load(force: true),
        child: _loading && _stories.isEmpty
            ? const Center(child: CircularProgressIndicator(color: DiggColors.green))
            : _error != null && _stories.isEmpty
                ? _ErrorState(message: _error!, onRetry: () => _load(force: true))
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _StatBar(status: _status, fromCache: _fromCache)),
                      SliverList.builder(
                        itemCount: _stories.length,
                        itemBuilder: (_, i) => StoryCard(
                          story: _stories[i],
                          index: i,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StoryScreen(client: widget.client, slug: _stories[i].slug),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final TrendingStatus? status;
  final bool fromCache;
  const _StatBar({required this.status, required this.fromCache});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final pieces = <Widget>[];
    if (s?.storiesToday != null) {
      pieces.add(_pill('${s!.storiesToday}', 'stories today'));
    }
    if (s?.clustersToday != null) {
      pieces.add(_pill('${s!.clustersToday}', 'clusters'));
    }
    if (fromCache) pieces.add(_pill('•', 'cached'));
    if (pieces.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DiggColors.border)),
      ),
      child: Wrap(spacing: 14, runSpacing: 6, children: pieces),
    );
  }

  Widget _pill(String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(color: DiggColors.green, fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: DiggColors.fgSoft, fontSize: 12),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.wifi_off, size: 40, color: DiggColors.fgSoft),
        const SizedBox(height: 12),
        const Text(
          'Couldn’t reach digg.com',
          textAlign: TextAlign.center,
          style: TextStyle(color: DiggColors.fg, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: DiggColors.fgSoft, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Center(child: FilledButton(onPressed: onRetry, child: const Text('Retry'))),
      ],
    );
  }
}
