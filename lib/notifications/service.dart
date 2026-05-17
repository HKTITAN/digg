// Notifications stub.
//
// v0.1.0 ships without OS-level notifications. We had `flutter_local_notifications`
// pinned at 17.x (requires Android core library desugaring → extra Gradle plumbing)
// then 16.x (compiles against older Android SDKs only — fails on the current
// AGP/SDK pair in CI). Neither is worth dragging into v0.1.0; the in-app
// poller still updates `storiesToday` so the UI shows fresh counts on launch.
//
// When this comes back: re-add `flutter_local_notifications: ^17.x` and the
// `coreLibraryDesugaring` block in `android/app/build.gradle.kts`.

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  Future<void> init() async {
    // no-op
  }

  Future<void> showNewStories({
    required int newCount,
    required String? topHeadline,
  }) async {
    // no-op — keeps callers compiling unchanged.
  }
}
