<p align="center">
  <img src=".github/assets/digg-logo.svg" alt="DIGG" height="80">
</p>

<h1 align="center">Digg — Native app for Android & Windows</h1>

A native Flutter client for [Digg](https://digg.com) — AI news, ranked. Trending feed, in-app story reader with engagement sparklines and sentiment breakdowns, profile lookup with Gravity / Vibe / Topic distributions, full-text search, on-disk cache for offline reading, and a background poller that fires a local notification when new stories land.

> ⚠️ **Experimental personal project. Use cautiously.**
> Built by [@HKTITAN](https://github.com/HKTITAN). Not affiliated with, endorsed by, or supported by Digg. The app reads public Digg pages — if Digg changes its layout, parts will silently break until I update the parser. No warranty, no support guarantees. Don't rely on it for anything that matters.

---

## What you get

- **Trending feed** — top stories from `digg.com/ai`, ranked, with author avatar stacks.
- **In-app story reader** — headline, TL;DR, full summary, totals strip, **cluster engagement** with 4 sparklines (Views / Comments / Reposts / Bookmarks), **multi-mode sentiment** (Raw / Story-weighted / User-weighted / Guarded), **analysis caveats**, and the full **posts list** with author + category badge + post content + engagement + "Open on X →" deep-link.
- **Profile** — AI Classification, Category, Gravity / Top followers / Followers, Vibe and Topic distribution chips, "Featured in" stories.
- **Search** — stories, people, repos with debounced live results.
- **Offline cache** — every fetch is persisted to a Hive box on disk. **Entries are kept for 7 days**, then evicted on launch. The API layer is stale-while-revalidate: a fresh fetch is tried first, and falls back to the on-disk copy when the network fails.
- **Background notifications** — Android uses WorkManager to poll Digg every ~15 minutes (the platform minimum) and fires a local notification when the story count goes up. Windows runs an in-app foreground timer (Windows doesn't expose persistent background workers to unprivileged apps without an installed service).

## Screens

- **Trending tab** — feed + cache state badge
- **Search tab** — stories / people / repos
- **Story screen** — full reader
- **Profile screen** — pushed from anywhere
- **Settings tab** — test notifications, re-register the background poller, clear the cache, version info

## Stack

| Concern | Choice |
|---|---|
| UI | Flutter 3.22+ / Dart 3.3+ |
| State | StatefulWidget (no external state lib — kept dependencies lean) |
| HTTP | `http` |
| HTML/RSC parsing | Hand-written (`lib/api/parser.dart`) — ports the browser-extension parsers |
| Cache | `hive` + `hive_flutter`, 7-day TTL |
| Notifications | `flutter_local_notifications` (Android channel + Windows toast) |
| Background | `workmanager` (Android) + `Timer.periodic` (Windows) |
| SVG | `flutter_svg` |

## Data sources

All against `https://digg.com`:

| Source | Used for |
|---|---|
| `GET /u/x/{username}` | Profile (AI Classification, Category, Gravity, Vibe, Topics) |
| `GET /ai` | Trending feed (`storiesByFilter.top.items`) |
| `GET /ai/{shortId}` | Story detail (JSON-LD + RSC stream + rendered HTML for post content) |
| `GET /api/search/{stories,users,repos}?q=&limit=` | Search & "Featured in" lookups |
| `GET /api/trending/status` | Background poller — new-story detection |

Three layers of parsing per page:
1. **`<script type="application/ld+json">`** — bulletproof, server-rendered every time. Primary source for headlines / descriptions / dates / authors.
2. **React Server Components stream** (`self.__next_f.push([1, "…"])`) — secondary source for `vibeDistribution`, `topicDistribution`, `snapshots[]`, `sentimentPercentages`, `caveats[]`, etc.
3. **Server-rendered HTML** — only place post **content** lives. Each `x.com/{handle}/status/{id}` link is paired with the adjacent `<p class="whitespace-pre-wrap …">` paragraphs in the same card.

If the RSC stream is partially corrupt, the JSON-LD fallback keeps the app rendering. Stories always show *something* as long as digg.com returned the page.

## Build & run

You need [Flutter](https://flutter.dev/docs/get-started/install) 3.22 or later on the build machine.

```bash
git clone https://github.com/HKTITAN/digg
cd digg

# Scaffold platform folders (regenerates anything missing; our pre-staged
# AndroidManifest.xml and lib/ code are preserved).
flutter create . --platforms=android,windows --org com.hktitan

flutter pub get

# Generate launcher icons from assets/icon/icon-source.png
dart run flutter_launcher_icons

# Android — connect a device or start an emulator first.
flutter run -d android

# Windows
flutter run -d windows

# Release builds
flutter build apk --release
flutter build windows --release
```

The Android APK lands at `build/app/outputs/flutter-apk/app-release.apk`. The Windows EXE bundle is at `build/windows/x64/runner/Release/`.

## Project layout

```
digg/
├── lib/
│   ├── main.dart              Entry — boots cache + notifications + poller
│   ├── theme.dart             Color palette + ThemeData
│   ├── api/
│   │   ├── client.dart        HTTP client + cached gets (stale-while-revalidate)
│   │   └── parser.dart        JSON-LD + RSC + HTML extractors
│   ├── models/models.dart     Story / Post / Profile / Snapshot / TrendingStatus
│   ├── storage/cache.dart     Hive box with 7-day TTL + sweep
│   ├── notifications/service.dart
│   ├── background/poller.dart WorkManager (Android) + Timer (Windows)
│   └── ui/
│       ├── app.dart           Root + bottom nav
│       ├── widgets/           DiggMark, DiggWordmark, Sparkline, StoryCard
│       └── screens/           home, story, profile, search, settings
├── assets/icon/               Source icons for flutter_launcher_icons
├── android/app/src/main/AndroidManifest.xml   Notification + WorkManager perms
├── .github/assets/            README artwork + logo
├── pubspec.yaml
└── README.md
```

## Caching strategy

- Every API call writes its result to a Hive entry keyed by the request shape, with an expiry of `now + 7 days`.
- Reads return the entry if not expired; if expired, the entry is treated as missing and a fresh fetch runs.
- On network failure, the API client falls back to *expired* entries (the `allowStale: true` path in `DiggCache.read`) so the app stays usable offline even past the week mark.
- A background sweep evicts every expired entry on app launch and after each background poll, so the cache size stays bounded.
- The Settings tab shows the current entry count and exposes a manual Clear button.

## Notification model

- A single Android channel `digg_trending` with default importance — no spammy heads-up alerts.
- The poller compares the current `storiesToday` against the value it stored last time; only fires on a positive delta.
- One notification ID per calendar day, so multiple background passes within one day update the existing notification rather than stacking new ones.
- Tapping the notification opens the app to the Trending tab (default behavior).

## Trademark / legal

Digg is a trademark of its owner. This app is an unaffiliated personal client that reads public Digg pages. The Digg logo is included only for identification, in line with normal client/branding conventions. If you're from Digg or X and would like a change made, please open an issue.

## License

No license declared — treat as all-rights-reserved unless you reach out. This is a personal project shared as-is for individual non-commercial use.
