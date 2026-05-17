// Background polling — checks Digg's trending status every ~15 minutes, fires
// a local notification when the story count goes up since the last check.
//
// Android: WorkManager schedules a periodic worker that survives app kills.
// Windows: foreground timer (the OS has no equivalent of a persistent
//   background worker for non-service apps without elevated privileges).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../api/client.dart';
import '../notifications/service.dart';
import '../storage/cache.dart';

const _kTaskTag = 'digg_trending_poll';

class BackgroundPoller {
  static final BackgroundPoller instance = BackgroundPoller._();
  BackgroundPoller._();

  Timer? _desktopTimer;

  /// Wire up the platform-appropriate poller. Safe to call multiple times.
  Future<void> start() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Workmanager().initialize(
        _callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      await Workmanager().registerPeriodicTask(
        _kTaskTag,
        _kTaskTag,
        frequency: const Duration(minutes: 15), // Android minimum
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      _desktopTimer ??= Timer.periodic(const Duration(minutes: 5), (_) {
        // Run inline — no isolate needed on desktop.
        _checkOnce();
      });
      // Fire once on startup so the user gets a fresh count immediately.
      unawaited(_checkOnce());
    }
  }

  Future<void> stop() async {
    _desktopTimer?.cancel();
    _desktopTimer = null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Workmanager().cancelByUniqueName(_kTaskTag);
    }
  }
}

/// One iteration of the poll, shared by both platforms. We track the last
/// seen story count in Hive and notify on a delta.
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
      // Pull the top story so we can put its headline in the notification.
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
    // Background failures are swallowed — there's no UI to surface them to.
  }
}

/// Android isolate entry. Must be a top-level function annotated with
/// @pragma so AOT doesn't strip it.
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _kTaskTag) await _checkOnce();
    return true;
  });
}
