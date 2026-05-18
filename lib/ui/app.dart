import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../storage/cache.dart';
import '../sync/sync_manager.dart';
import '../theme.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';

/// On desktop, Flutter's default ScrollBehavior excludes mouse from
/// `dragDevices` — so click-and-drag to scroll silently doesn't work, and
/// the scrollbar isn't shown by default. This behavior re-enables both,
/// plus trackpad and stylus. Without this, the Windows build scrolls only
/// via the mouse wheel and feels broken everywhere else.
class _DiggScrollBehavior extends MaterialScrollBehavior {
  const _DiggScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    // Always show a thin scrollbar on desktop so the user has a clear
    // affordance.
    switch (Theme.of(context).platform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: false,
          child: child,
        );
      default:
        return child;
    }
  }
}

class DiggApp extends StatelessWidget {
  final DiggClient client;
  final DiggCache cache;
  final DiggSyncManager sync;
  const DiggApp({super.key, required this.client, required this.cache, required this.sync});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digg',
      debugShowCheckedModeBanner: false,
      theme: buildDiggTheme(),
      scrollBehavior: const _DiggScrollBehavior(),
      home: _Root(client: client, cache: cache, sync: sync),
    );
  }
}

class _Root extends StatefulWidget {
  final DiggClient client;
  final DiggCache cache;
  final DiggSyncManager sync;
  const _Root({required this.client, required this.cache, required this.sync});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(client: widget.client, sync: widget.sync),
      SearchScreen(client: widget.client),
      SettingsScreen(cache: widget.cache, sync: widget.sync),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: DiggColors.bg,
        indicatorColor: DiggColors.greenSoft,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Trending'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
