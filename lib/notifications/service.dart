// Cross-platform local notifications. Android uses native channels; Windows
// goes through the Action Center via the Windows toast plugin built into
// flutter_local_notifications.

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
    final init = InitializationSettings(
      android: androidInit,
      windows: defaultTargetPlatform == TargetPlatform.windows
          ? const WindowsInitializationSettings(
              appName: 'Digg',
              appUserModelId: 'com.hktitan.digg',
              guid: 'b1a55c8e-3c2d-4f5a-9e0b-3a6e0c8f1d2e',
            )
          : null,
    );
    await _plugin.initialize(init);

    // Android 13+ requires runtime opt-in or the tray gets nothing.
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _ready = true;
  }

  Future<void> showNewStories({
    required int newCount,
    required String? topHeadline,
  }) async {
    if (!_ready) await init();
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
        windows: WindowsNotificationDetails(),
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
