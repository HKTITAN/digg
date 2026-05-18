// Digg — native Android + Windows client.
// Personal project. Reads public Digg pages. Not affiliated with Digg.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api/client.dart';
import 'background/poller.dart';
import 'notifications/service.dart';
import 'storage/cache.dart';
import 'ui/app.dart';

Future<void> main() async {
  // Catch every error path so the app always reaches runApp() — even if a
  // plugin init or storage open throws, we want a visible UI to mount
  // rather than a closed-immediately APK (which is what the user saw in
  // v0.1.2 on Android).
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('Flutter error: ${details.exception}');
    };

    final cache = DiggCache();
    try {
      await cache.init();
    } catch (e, st) {
      debugPrint('Cache init failed (continuing on in-memory only): $e\n$st');
    }

    // Notifications + foreground poller are best-effort. A failure here
    // must not stop the app from rendering.
    unawaited(_safeInit('notifications', NotificationService.instance.init));
    unawaited(_safeInit('background poller', BackgroundPoller.instance.start));

    final client = DiggClient(cache: cache);
    runApp(DiggApp(client: client, cache: cache));
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

Future<void> _safeInit(String label, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e, st) {
    debugPrint('$label init failed (continuing): $e\n$st');
  }
}
