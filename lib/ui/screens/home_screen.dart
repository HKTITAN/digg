import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/client.dart';
import '../../models/models.dart';
import '../../sync/sync_manager.dart';
import '../../theme.dart';
import '../widgets/author_strip.dart';
import '../widgets/digg_logo.dart';
import '../widgets/repo_strip.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/story_card.dart';
import 'profile_screen.dart';
import 'rankings_screen.dart';
import 'repos_screen.dart';
import 'story_screen.dart';

class HomeScreen extends StatefulWidget {
  final DiggClient client;
  final DiggSyncManager sync;
  const HomeScreen({super.key, required this.client, required this.sync});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FeedResult? _feed;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    if (_feed == null) setState(() => _loading = true);
    try {
      final r = await widget.client.getFeed(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        _feed = r;
        _loading = false;
        _error = null;
      });
      // Background prefetch — the sync engine diffs the new feed against
      // the local index and only fetches what's actually changed.
      unawaited(widget.sync.sync(force: force));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openStory(String slug) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: StoryScreen(client: widget.client, slug: slug),
        ),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  void _openProfile(String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(client: widget.client, username: username),
      ),
    );
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
    final feed = _feed;
    if (_loading && feed == null) {
      return const Column(
        children: [
          _StatBarSkeleton(),
          Expanded(child: FeedSkeleton(count: 6)),
        ],
      );
    }
    if (_error != null && feed == null) {
      return _ErrorState(message: _error!, onRetry: () => _load(force: true));
    }
    if (feed == null || feed.stories.isEmpty) {
      return const _EmptyState();
    }
    return _RichHomeBody(
      feed: feed,
      sync: widget.sync,
      onStory: _openStory,
      onAuthor: (a) => _openProfile(a.username),
      onRepo: (r) => launchUrl(Uri.parse(r.url)),
      onAllAuthors: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RankingsScreen(client: widget.client),
        ),
      ),
      onAllRepos: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReposScreen(client: widget.client),
        ),
      ),
    );
  }
}

class _RichHomeBody extends StatelessWidget {
  final FeedResult feed;
  final DiggSyncManager sync;
  final void Function(String slug) onStory;
  final void Function(AuthorCard) onAuthor;
  final void Function(RepoCard) onRepo;
  final VoidCallback onAllAuthors;
  final VoidCallback onAllRepos;

  const _RichHomeBody({
    required this.feed,
    required this.sync,
    required this.onStory,
    required this.onAuthor,
    required this.onRepo,
    required this.onAllAuthors,
    required this.onAllRepos,
  });

  @override
  Widget build(BuildContext context) {
    // Interleave story chunks with sidebar strips so the home feels like a
    // magazine cover rather than a flat list.
    final stories = feed.stories;
    final firstChunk = stories.take(6).toList();
    final secondChunk = stories.skip(6).take(8).toList();
    final tailChunk = stories.skip(14).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _StatBar(status: feed.status, fromCache: feed.fromCache, sync: sync)),

        // ----- Trending head -----
        const SliverToBoxAdapter(
          child: SectionHeader(title: 'Trending now'),
        ),
        SliverList.builder(
          itemCount: firstChunk.length,
          itemBuilder: (_, i) => StoryCard(
            story: firstChunk[i],
            index: i,
            onTap: () => onStory(firstChunk[i].slug),
          ),
        ),

        // ----- Top authors strip -----
        if (feed.topAuthors.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Top authors',
              aside: '${feed.topAuthors.length} ranked',
              onMore: onAllAuthors,
            ),
          ),
          SliverToBoxAdapter(
            child: AuthorStrip(
              authors: feed.topAuthors.take(20).toList(),
              onTap: onAuthor,
            ),
          ),
        ],

        // ----- Trending body -----
        if (secondChunk.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverList.builder(
            itemCount: secondChunk.length,
            itemBuilder: (_, i) => StoryCard(
              story: secondChunk[i],
              index: 6 + i,
              onTap: () => onStory(secondChunk[i].slug),
            ),
          ),
        ],

        // ----- GitHub recent stars strip -----
        if (feed.githubRecentStars.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'AI is starring',
              aside: 'GitHub',
              onMore: onAllRepos,
            ),
          ),
          SliverToBoxAdapter(
            child: RepoStrip(
              repos: feed.githubRecentStars.take(20).toList(),
              onTap: onRepo,
            ),
          ),
        ],

        // ----- Trending tail -----
        if (tailChunk.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverList.builder(
            itemCount: tailChunk.length,
            itemBuilder: (_, i) => StoryCard(
              story: tailChunk[i],
              index: 14 + i,
              onTap: () => onStory(tailChunk[i].slug),
            ),
          ),
        ],

        // ----- Up & coming -----
        if (feed.upAndComing.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Up & coming', aside: 'gaining velocity'),
          ),
          SliverList.builder(
            itemCount: feed.upAndComing.take(6).length,
            itemBuilder: (_, i) => StoryCard(
              story: feed.upAndComing[i],
              index: i,
              onTap: () => onStory(feed.upAndComing[i].slug),
            ),
          ),
        ],

        // ----- Yesterday's top -----
        if (feed.yesterdayTop.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Yesterday', aside: 'top stories'),
          ),
          SliverList.builder(
            itemCount: feed.yesterdayTop.take(6).length,
            itemBuilder: (_, i) => StoryCard(
              story: feed.yesterdayTop[i],
              index: i,
              onTap: () => onStory(feed.yesterdayTop[i].slug),
            ),
          ),
        ],

        // ----- From the web -----
        if (feed.hackerNews.isNotEmpty || feed.techmeme.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'From the web', aside: 'Hacker News · Techmeme'),
          ),
          SliverList.builder(
            itemCount: feed.hackerNews.length + feed.techmeme.length,
            itemBuilder: (_, i) {
              final link = i < feed.hackerNews.length
                  ? feed.hackerNews[i]
                  : feed.techmeme[i - feed.hackerNews.length];
              final source = i < feed.hackerNews.length ? 'HN' : 'TM';
              return _ExternalLinkRow(link: link, source: source);
            },
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _ExternalLinkRow extends StatelessWidget {
  final ExternalLink link;
  final String source;
  const _ExternalLinkRow({required this.link, required this.source});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(link.url)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: DiggColors.border.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: DiggColors.greenSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                source,
                style: const TextStyle(
                  color: DiggColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                link.title,
                style: const TextStyle(
                  color: DiggColors.fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            const Icon(Icons.north_east, size: 14, color: DiggColors.fgSoft),
          ],
        ),
      ),
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
    } else if (result != null && result.totalKnown > 0) {
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
