// Digg — native Android + Windows client.
// Personal project. Reads public Digg pages. Not affiliated with Digg.

import 'dart:async';

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

  // Notifications + the foreground poller are best-effort. If a platform
  // lacks the plumbing (or the user denied permission) the app still works.
  await NotificationService.instance.init();
  unawaited(BackgroundPoller.instance.start());

  final client = DiggClient(cache: cache);

  runApp(DiggApp(client: client, cache: cache));
}

