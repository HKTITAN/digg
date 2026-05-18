// Digg — native Android + Windows client.
// Personal project. Reads public Digg pages. Not affiliated with Digg.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api/client.dart';
import 'background/poller.dart';
import 'notifications/service.dart';
import 'storage/cache.dart';
import 'sync/sync_manager.dart';
import 'ui/app.dart';

Future<void> main() async {
  // Catch every error path so the app always reaches runApp(), even if a
  // plugin init or storage open throws. The closed-on-launch APK from
  // v0.1.2 happened because the init chain crashed *before* runApp; this
  // shell guarantees the UI mounts.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exception}');
    };

    final cache = DiggCache();
    try { await cache.init(); }
    catch (e, st) { debugPrint('Cache init failed: $e\n$st'); }

    final client = DiggClient(cache: cache);
    final sync = DiggSyncManager(client: client, cache: cache);
    await sync.loadLastResult();

    // Notifications + poller are best-effort. Failures must not stop the
    // app from rendering.
    unawaited(_safeInit('notifications', NotificationService.instance.init));
    unawaited(_safeInit('background poller', () => BackgroundPoller.instance.start(sync: sync)));

    runApp(DiggApp(client: client, cache: cache, sync: sync));
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

Future<void> _safeInit(String label, Future<void> Function() fn) async {
  try { await fn(); }
  catch (e, st) { debugPrint('$label init failed (continuing): $e\n$st'); }
}
