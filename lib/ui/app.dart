import 'package:flutter/material.dart';

import '../api/client.dart';
import '../storage/cache.dart';
import '../theme.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';

class DiggApp extends StatelessWidget {
  final DiggClient client;
  final DiggCache cache;
  const DiggApp({super.key, required this.client, required this.cache});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digg',
      debugShowCheckedModeBanner: false,
      theme: buildDiggTheme(),
      home: _Root(client: client, cache: cache),
    );
  }
}

class _Root extends StatefulWidget {
  final DiggClient client;
  final DiggCache cache;
  const _Root({required this.client, required this.cache});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(client: widget.client),
      SearchScreen(client: widget.client),
      SettingsScreen(cache: widget.cache),
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
