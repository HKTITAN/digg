// In-app foreground poller. Runs the sync engine on a 5-minute timer and
// fires a local notification when the day's story count goes up.
//
// Honest scope: this runs only while the Dart isolate is alive. On Android
// the OS suspends background isolates aggressively; persistent off-screen
// polling needs a foreground service or WorkManager binding, both of
// which were tried and rejected as too brittle for v0.1. For now,
// notifications fire on app launch and while the app is in the foreground.

import 'dart:async' show Timer, unawaited;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../notifications/service.dart';
import '../sync/sync_manager.dart';

class BackgroundPoller {
  static final BackgroundPoller instance = BackgroundPoller._();
  BackgroundPoller._();

  Timer? _timer;
  DiggSyncManager? _sync;
  static const _interval = Duration(minutes: 5);

  /// Wire up the poller. Safe to call multiple times — re-arming overwrites.
  Future<void> start({required DiggSyncManager sync}) async {
    _timer?.cancel();
    _sync = sync;
    // Fire once immediately so the user gets fresh content on launch.
    unawaited(_checkOnce());
    _timer = Timer.periodic(_interval, (_) => _checkOnce());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkOnce() async {
    final sync = _sync;
    if (sync == null) return;
    try {
      // Snapshot the prior story count before syncing.
      final box = await Hive.openBox('digg_poller_v1');
      final lastSeen = (box.get('lastStoriesToday') as int?) ?? 0;

      // Sync — pulls the feed, prefetches new/updated stories.
      final result = await sync.sync();
      if (result == null) return;

      // The first sync of the day will surface `newSlugs` for everything
      // currently trending. We only want to notify on *fresh* additions
      // detected after the first sync, so we gate on lastSeen != 0.
      if (lastSeen != 0 && result.newSlugs > 0) {
        await NotificationService.instance.showNewStories(
          newCount: result.newSlugs,
          topHeadline: null,
        );
      }
      await box.put('lastStoriesToday', result.totalKnown);
    } catch (_) {
      // Background failures are swallowed — there's no UI to surface them.
    }
  }
}
