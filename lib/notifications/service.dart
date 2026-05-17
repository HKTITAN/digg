// Cross-platform local notifications.
//
// Android uses native channels via flutter_local_notifications. Windows
// support in flutter_local_notifications 17.x is separate from the main
// plugin and not wired in here yet — on Windows the service initialises
// cleanly but show() is a no-op until we bolt on flutter_local_notifications_windows.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;

    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const init = InitializationSettings(android: androidInit);
    await _plugin.initialize(init);

    // Android 13+ requires runtime opt-in or the tray gets nothing.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    }

    _ready = true;
  }

  Future<void> showNewStories({
    required int newCount,
    required String? topHeadline,
  }) async {
    if (!_ready) await init();
    // Windows support lives in a separate plugin (flutter_local_notifications_windows)
    // which we haven't wired in. Skip cleanly on non-Android for now.
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final body = topHeadline != null && topHeadline.isNotEmpty
        ? topHeadline
        : '$newCount new ${newCount == 1 ? "story" : "stories"} on Digg';

    await _plugin.show(
      _idForToday(),
      newCount == 1 ? 'New story on Digg' : '$newCount new stories on Digg',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'digg_trending',
          'Digg trending',
          channelDescription: 'New stories detected on Digg',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ticker: 'Digg',
          color: Color(0xFF00BA7C),
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  /// One notification per day at most — we slot it into a fixed ID so the
  /// tray doesn't fill up with duplicates if the background worker fires
  /// multiple times.
  int _idForToday() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }
}
