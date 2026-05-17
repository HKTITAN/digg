// Digg — native Android + Windows client.
// Personal project. Reads public Digg pages. Not affiliated with Digg.

import 'package:flutter/material.dart';

import 'api/client.dart';
import 'background/poller.dart';
import 'notifications/service.dart';
import 'storage/cache.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cache = DiggCache();
  await cache.init();

  // Notifications + background polling are best-effort. If a platform lacks
  // the plumbing (or the user denied permission) the app still works fine.
  await NotificationService.instance.init();
  unawaited_(BackgroundPoller.instance.start());

  final client = DiggClient(cache: cache);

  runApp(DiggApp(client: client, cache: cache));
}

// `unawaited` from dart:async without importing the whole package symbol set.
void unawaited_(Future<void> _) {}
