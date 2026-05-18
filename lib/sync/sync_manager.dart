// Sync manager — the git-like "fetch what's missing" engine for Digg.
//
// Why this exists: Digg's feed lists ~30-60 trending stories at any time.
// Re-fetching every one of them on every refresh is wasteful and hits
// digg.com hard. Instead we maintain a small local *index* of every slug
// we've ever seen, with a freshness marker per entry. On each sync:
//
//   1. Re-fetch the feed (cheap — one request).
//   2. Diff the feed against the local index. Anything new is queued.
//      Anything whose `postCount` has grown since we last saw it is also
//      queued (the story has new posts → re-fetch).
//   3. Drain the queue with a concurrency cap (default 3) and a minimum
//      per-story refetch interval (default 1 h) so a story that updates
//      rapidly doesn't get hammered.
//   4. Persist the updated index, marking each successful prefetch's
//      `lastFetchedAt`. The index itself is kept for 30 days; individual
//      story bodies stay in the regular 7-day Hive cache so the app
//      works fully offline for a week.
//
// The index is intentionally tiny (~5 KB even at 200 entries) so it's
// cheap to load on launch and survives Hive corruption (kept under a
// separate cache key).

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../storage/cache.dart';

/// One entry in the local sync index.
class SyncEntry {
  final String slug;
  final int? rank;
  final int? postCount;
  final String? createdAt;
  /// Last successful body fetch (millisSinceEpoch). Null if we've only
  /// ever seen the slug in the feed, never opened the story.
  final int? lastFetchedAt;
  /// First time this slug appeared in any sync (millisSinceEpoch).
  final int firstSeenAt;

  const SyncEntry({
    required this.slug,
    this.rank,
    this.postCount,
    this.createdAt,
    this.lastFetchedAt,
    required this.firstSeenAt,
  });

  SyncEntry copyWith({
    int? rank,
    int? postCount,
    String? createdAt,
    int? lastFetchedAt,
  }) =>
      SyncEntry(
        slug: slug,
        rank: rank ?? this.rank,
        postCount: postCount ?? this.postCount,
        createdAt: createdAt ?? this.createdAt,
        lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
        firstSeenAt: firstSeenAt,
      );

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'rank': rank,
        'postCount': postCount,
        'createdAt': createdAt,
        'lastFetchedAt': lastFetchedAt,
        'firstSeenAt': firstSeenAt,
      };

  factory SyncEntry.fromJson(Map j) => SyncEntry(
        slug: j['slug'] as String,
        rank: j['rank'] as int?,
        postCount: j['postCount'] as int?,
        createdAt: j['createdAt'] as String?,
        lastFetchedAt: j['lastFetchedAt'] as int?,
        firstSeenAt: (j['firstSeenAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      );
}

/// Result of one sync pass — surfaced to the UI for the status bar.
class SyncResult {
  final int totalKnown;
  final int newSlugs;
  final int updatedSlugs;
  final int prefetched;
  final int failed;
  final int skippedByRateLimit;
  final DateTime syncedAt;

  const SyncResult({
    required this.totalKnown,
    required this.newSlugs,
    required this.updatedSlugs,
    required this.prefetched,
    required this.failed,
    required this.skippedByRateLimit,
    required this.syncedAt,
  });

  Map<String, dynamic> toJson() => {
        'totalKnown': totalKnown,
        'newSlugs': newSlugs,
        'updatedSlugs': updatedSlugs,
        'prefetched': prefetched,
        'failed': failed,
        'skippedByRateLimit': skippedByRateLimit,
        'syncedAt': syncedAt.millisecondsSinceEpoch,
      };

  factory SyncResult.fromJson(Map j) => SyncResult(
        totalKnown: (j['totalKnown'] as int?) ?? 0,
        newSlugs: (j['newSlugs'] as int?) ?? 0,
        updatedSlugs: (j['updatedSlugs'] as int?) ?? 0,
        prefetched: (j['prefetched'] as int?) ?? 0,
        failed: (j['failed'] as int?) ?? 0,
        skippedByRateLimit: (j['skippedByRateLimit'] as int?) ?? 0,
        syncedAt: DateTime.fromMillisecondsSinceEpoch((j['syncedAt'] as int?) ?? 0),
      );
}

class DiggSyncManager {
  final DiggClient client;
  final DiggCache cache;

  /// Concurrent in-flight story fetches. Keeping this small (3) so we
  /// never look like an abuser to digg.com.
  static const int _concurrency = 3;

  /// Don't refetch the same story body more than once per this window
  /// even if it appears to have grown. Tunable.
  static const Duration _minRefetchInterval = Duration(hours: 1);

  /// Index cache key — kept under a separate key from individual stories.
  static const String _indexKey = 'sync:index_v1';

  /// Most recent SyncResult — exposed to the UI.
  static const String _lastResultKey = 'sync:lastResult_v1';

  /// Allow the in-app status bar / settings screen to watch sync state.
  final ValueNotifier<SyncResult?> lastResult = ValueNotifier(null);
  final ValueNotifier<bool> running = ValueNotifier(false);

  bool _disposed = false;

  DiggSyncManager({required this.client, required this.cache});

  // ----- public API -----

  Future<void> loadLastResult() async {
    final stored = await cache.read(_lastResultKey, allowStale: true);
    if (stored != null) {
      try { lastResult.value = SyncResult.fromJson(stored); } catch (_) {}
    }
  }

  /// Run one sync pass. Safe to call concurrently — duplicate calls
  /// short-circuit on the [running] guard.
  Future<SyncResult?> sync({bool force = false}) async {
    if (_disposed || running.value) return null;
    running.value = true;
    try {
      final index = await _loadIndex();
      final feedRes = await client.getFeed(forceRefresh: force);
      final now = DateTime.now();

      // Build the next index by merging the feed into the stored index.
      // Preserve `lastFetchedAt` and `firstSeenAt` from the prior entry
      // so we can decide whether to re-prefetch later.
      final next = <String, SyncEntry>{...index};
      final toFetch = <String>[];
      var newSlugs = 0;
      var updatedSlugs = 0;
      var skipped = 0;

      for (final story in feedRes.stories) {
        if (story.slug.isEmpty) continue;
        final prior = index[story.slug];
        final updated = prior == null
            ? SyncEntry(
                slug: story.slug,
                rank: story.rank,
                postCount: story.postCount,
                createdAt: story.createdAt,
                firstSeenAt: now.millisecondsSinceEpoch,
              )
            : prior.copyWith(
                rank: story.rank,
                postCount: story.postCount,
                createdAt: story.createdAt,
              );
        next[story.slug] = updated;

        // Decide whether to enqueue a body fetch.
        final isNew = prior == null;
        final hasMorePosts = prior != null &&
            (story.postCount ?? 0) > (prior.postCount ?? 0);
        if (!isNew && !hasMorePosts) continue;

        final lastFetched = updated.lastFetchedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updated.lastFetchedAt!);
        final withinCooldown = lastFetched != null &&
            now.difference(lastFetched) < _minRefetchInterval;
        if (withinCooldown) {
          skipped++;
          continue;
        }

        if (isNew) newSlugs++;
        else if (hasMorePosts) updatedSlugs++;
        toFetch.add(story.slug);
      }

      // Drain the prefetch queue with a concurrency cap.
      var prefetched = 0;
      var failed = 0;
      final iterator = toFetch.iterator;
      final workers = List.generate(_concurrency, (_) async {
        while (true) {
          String? slug;
          if (iterator.moveNext()) slug = iterator.current;
          if (slug == null) return;
          try {
            await client.getStory(slug);
            next[slug] = next[slug]!.copyWith(
              lastFetchedAt: DateTime.now().millisecondsSinceEpoch,
            );
            prefetched++;
          } catch (e) {
            failed++;
            debugPrint('sync: prefetch failed for $slug: $e');
          }
        }
      });
      await Future.wait(workers);

      await _saveIndex(next);

      final result = SyncResult(
        totalKnown: next.length,
        newSlugs: newSlugs,
        updatedSlugs: updatedSlugs,
        prefetched: prefetched,
        failed: failed,
        skippedByRateLimit: skipped,
        syncedAt: DateTime.now(),
      );
      await cache.write(_lastResultKey, result.toJson(),
          customTtl: const Duration(days: 30));
      lastResult.value = result;
      return result;
    } catch (e, st) {
      debugPrint('sync: pass failed: $e\n$st');
      return null;
    } finally {
      running.value = false;
    }
  }

  /// Total number of cluster slugs in the local index (whether their
  /// bodies are cached or not). Surfaced on the settings screen.
  Future<int> knownStoryCount() async {
    final index = await _loadIndex();
    return index.length;
  }

  /// Drop the entire sync state. Useful if the user wants to start fresh.
  Future<void> reset() async {
    await cache.delete(_indexKey);
    await cache.delete(_lastResultKey);
    lastResult.value = null;
  }

  void dispose() {
    _disposed = true;
    lastResult.dispose();
    running.dispose();
  }

  // ----- persistence -----

  Future<Map<String, SyncEntry>> _loadIndex() async {
    final data = await cache.read(_indexKey, allowStale: true);
    if (data == null) return {};
    final raw = (data['entries'] as List?) ?? const [];
    final out = <String, SyncEntry>{};
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        final entry = SyncEntry.fromJson(Map<String, dynamic>.from(e));
        out[entry.slug] = entry;
      } catch (_) {}
    }
    return out;
  }

  Future<void> _saveIndex(Map<String, SyncEntry> index) async {
    await cache.write(
      _indexKey,
      {
        'entries': index.values.map((e) => e.toJson()).toList(),
        'syncedAt': DateTime.now().millisecondsSinceEpoch,
      },
      customTtl: const Duration(days: 30),
    );
  }
}
