import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../models/models.dart';
import '../../sync/sync_manager.dart';
import '../../theme.dart';
import '../widgets/digg_logo.dart';
import '../widgets/skeleton.dart';
import '../widgets/story_card.dart';
import 'story_screen.dart';

class HomeScreen extends StatefulWidget {
  final DiggClient client;
  final DiggSyncManager sync;
  const HomeScreen({super.key, required this.client, required this.sync});

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
    if (_stories.isEmpty) setState(() => _loading = true);
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
      // Kick the sync engine in the background — it'll diff the new feed
      // against the local index and prefetch only stories that are new or
      // have new posts. Doesn't block the UI; the user gets the list
      // immediately and the bodies fill in behind the scenes.
      unawaited(widget.sync.sync(force: force));
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
        backgroundColor: DiggColors.bgSoft,
        onRefresh: () => _load(force: true),
        child: _bodyContent(),
      ),
    );
  }

  Widget _bodyContent() {
    if (_loading && _stories.isEmpty) {
      // Skeleton scaffold matches the eventual layout — single column of
      // story-card-shaped placeholders behind a small stat-bar skeleton.
      return const Column(
        children: [
          _StatBarSkeleton(),
          Expanded(child: FeedSkeleton(count: 6)),
        ],
      );
    }
    if (_error != null && _stories.isEmpty) {
      return _ErrorState(message: _error!, onRetry: () => _load(force: true));
    }
    if (_stories.isEmpty) {
      return const _EmptyState();
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _StatBar(status: _status, fromCache: _fromCache, sync: widget.sync)),
        SliverList.builder(
          itemCount: _stories.length,
          itemBuilder: (_, i) => StoryCard(
            story: _stories[i],
            index: i,
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, anim, __) => FadeTransition(
                  opacity: anim,
                  child: StoryScreen(client: widget.client, slug: _stories[i].slug),
                ),
                transitionDuration: const Duration(milliseconds: 220),
                reverseTransitionDuration: const Duration(milliseconds: 180),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _StatBar extends StatelessWidget {
  final TrendingStatus? status;
  final bool fromCache;
  final DiggSyncManager sync;
  const _StatBar({required this.status, required this.fromCache, required this.sync});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: sync.running,
      builder: (_, running, __) => ValueListenableBuilder<SyncResult?>(
        valueListenable: sync.lastResult,
        builder: (_, result, __) => _build(context, running, result),
      ),
    );
  }

  Widget _build(BuildContext context, bool running, SyncResult? result) {
    final s = status;
    final pieces = <Widget>[];
    if (s?.storiesToday != null) {
      pieces.add(_pill('${s!.storiesToday}', 'stories today'));
    }
    if (running) {
      pieces.add(const _SyncingPill());
    } else if (result != null) {
      pieces.add(_pill('${result.totalKnown}', 'cached'));
      if (result.prefetched > 0) {
        pieces.add(_pill('+${result.prefetched}', 'fetched'));
      }
    }
    if (fromCache && !running) pieces.add(_pill('•', 'offline'));
    if (pieces.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DiggColors.border.withValues(alpha: 0.5))),
      ),
      child: Wrap(spacing: 14, runSpacing: 6, children: pieces),
    );
  }

  Widget _pill(String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
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

class _SyncingPill extends StatelessWidget {
  const _SyncingPill();
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 10, height: 10,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: DiggColors.green),
        ),
        SizedBox(width: 6),
        Text('Syncing', style: TextStyle(color: DiggColors.fgSoft, fontSize: 12)),
      ],
    );
  }
}

class _StatBarSkeleton extends StatelessWidget {
  const _StatBarSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DiggColors.border.withValues(alpha: 0.5))),
      ),
      child: const Row(
        children: [
          Skeleton(width: 110, height: 11, radius: 4),
          SizedBox(width: 14),
          Skeleton(width: 90, height: 11, radius: 4),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_outlined, size: 56, color: DiggColors.fgSoft),
        const SizedBox(height: 16),
        const Text(
          'Couldn’t reach digg.com',
          textAlign: TextAlign.center,
          style: TextStyle(color: DiggColors.fg, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: DiggColors.fgSoft, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        Center(child: FilledButton(onPressed: onRetry, child: const Text('Retry'))),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: const [
        SizedBox(height: 96),
        Center(child: DiggMark(size: 48, color: DiggColors.fgSoft)),
        SizedBox(height: 16),
        Text(
          'No stories yet',
          textAlign: TextAlign.center,
          style: TextStyle(color: DiggColors.fg, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 6),
        Text(
          'Pull down to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(color: DiggColors.fgSoft, fontSize: 13),
        ),
      ],
    );
  }
}
