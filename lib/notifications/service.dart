// Local notifications. Android-only for now (Windows toast support needs
// the separate flutter_local_notifications_windows package and a registered
// AUMID, which we'll wire up in a later release).
//
// The Android side needs core library desugaring enabled in
// android/app/build.gradle.kts — the release workflow patches that
// automatically after `flutter create` runs.

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
    if (defaultTargetPlatform != TargetPlatform.android) {
      _ready = true;
      return;
    }
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const init = InitializationSettings(android: androidInit);
    await _plugin.initialize(init);

    // Android 13+ runtime opt-in — without this, nothing reaches the tray.
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
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final body = (topHeadline != null && topHeadline.isNotEmpty)
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

  /// One notification ID per calendar day so background passes update the
  /// existing notification instead of stacking duplicates.
  int _idForToday() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }
}
