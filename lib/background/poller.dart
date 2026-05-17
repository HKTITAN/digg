// In-app foreground poller. Checks Digg's trending status every ~5 minutes
// while the app is open and fires a local notification when the story
// count goes up since the last check.
//
// Honest scope: this runs only while the Dart isolate is alive. On Android
// the OS suspends background isolates aggressively; persistent off-screen
// polling needs a foreground service or WorkManager binding, both of
// which were tried and rejected as too brittle for v0.1. For now,
// notifications fire on app launch and while the app is in the foreground.

import 'dart:async' show Timer, unawaited;

import 'package:hive_flutter/hive_flutter.dart';

import '../api/client.dart';
import '../notifications/service.dart';
import '../storage/cache.dart';

class BackgroundPoller {
  static final BackgroundPoller instance = BackgroundPoller._();
  BackgroundPoller._();

  Timer? _timer;
  static const _interval = Duration(minutes: 5);

  /// Wire up the poller. Safe to call multiple times — re-arming overwrites.
  Future<void> start() async {
    _timer?.cancel();
    // Fire once immediately so the user gets a fresh count on launch.
    unawaited(_checkOnce());
    _timer = Timer.periodic(_interval, (_) => _checkOnce());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }
}

/// One iteration of the poll. Tracks the last seen story count in Hive and
/// only fires a notification on a positive delta.
Future<void> _checkOnce() async {
  try {
    final cache = DiggCache();
    await cache.init();
    final client = DiggClient(cache: cache);

    final status = await client.getTrendingStatus();
    if (status == null) return;
    final now = status.storiesToday ?? 0;
    if (now == 0) return;

    final box = await Hive.openBox('digg_poller_v1');
    final last = (box.get('lastStoriesToday') as int?) ?? 0;
    if (now > last) {
      String? topHeadline;
      try {
        final feed = await client.getFeed();
        topHeadline = feed.stories.isNotEmpty ? feed.stories.first.displayTitle : null;
      } catch (_) {}
      await NotificationService.instance.showNewStories(
        newCount: now - last,
        topHeadline: topHeadline,
      );
    }
    await box.put('lastStoriesToday', now);
    await cache.sweep();
  } catch (_) {
    // Swallow — there's no UI to surface background failures to.
  }
}

