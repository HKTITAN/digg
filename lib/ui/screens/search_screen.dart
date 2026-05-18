import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../layout.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton.dart';
import '../widgets/story_card.dart';
import 'profile_screen.dart';
import 'story_screen.dart';

class SearchScreen extends StatefulWidget {
  final DiggClient client;
  const SearchScreen({super.key, required this.client});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _kind = 'stories';
  String _q = '';
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;
  Timer? _debounce;

  // Default-state content — surfaced when the query is empty so the tab
  // doesn't look like a dead end before the user types anything.
  FeedResult? _browseFeed;

  @override
  void initState() {
    super.initState();
    _loadBrowse();
  }

  Future<void> _loadBrowse() async {
    try {
      final r = await widget.client.getFeed();
      if (mounted) setState(() => _browseFeed = r);
    } catch (_) {/* feed already shown on home — silent here */}
  }

  void _onQuery(String v) {
    _q = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _runSearch);
  }

  Future<void> _runSearch() async {
    final q = _q.trim();
    if (q.length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    final r = await widget.client.search(kind: _kind, q: q);
    if (!mounted) return;
    setState(() {
      _results = r;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isQuery = _q.trim().length >= 2;
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              autofocus: false,
              onChanged: _onQuery,
              style: const TextStyle(color: DiggColors.fg),
              decoration: const InputDecoration(
                hintText: 'Search stories, people, repos',
                prefixIcon: Icon(Icons.search, color: DiggColors.fgSoft),
              ),
            ),
          ),
          if (isQuery) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final k in const ['stories', 'people', 'repos'])
                    ChoiceChip(
                      label: Text(k[0].toUpperCase() + k.substring(1)),
                      selected: _kind == _apiKind(k),
                      onSelected: (_) {
                        setState(() => _kind = _apiKind(k));
                        _runSearch();
                      },
                      selectedColor: DiggColors.greenSoft,
                      backgroundColor: DiggColors.bgSoft,
                      side: BorderSide(
                          color: _kind == _apiKind(k) ? DiggColors.green : DiggColors.border),
                      labelStyle: TextStyle(
                        color: _kind == _apiKind(k) ? DiggColors.green : DiggColors.fg,
                        fontWeight: FontWeight.w700,
                        fontSize: isCompactWidth(context) ? 12 : 13,
                      ),
                      showCheckmark: false,
                    ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(color: DiggColors.green, minHeight: 1),
          ],
          Expanded(child: isQuery ? _resultsView() : _browseView()),
        ],
      ),
    );
  }

  // ----- Browse (no query yet) -----
  Widget _browseView() {
    final feed = _browseFeed;
    if (feed == null) {
      return const FeedSkeleton(count: 4);
    }
    final stories = feed.stories.take(12).toList();
    return ListView(
      children: [
        const SectionHeader(title: 'Trending today', aside: 'tap to read'),
        for (var i = 0; i < stories.length; i++)
          StoryCard(
            story: stories[i],
            index: i,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StoryScreen(client: widget.client, slug: stories[i].slug),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ----- Query results -----
  Widget _resultsView() {
    if (_results.isEmpty && !_loading) {
      return const Center(
        child: Text('No matches.', style: TextStyle(color: DiggColors.fgSoft)),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _row(_results[i]),
    );
  }

  String _apiKind(String label) => label == 'people' ? 'users' : label;

  Widget _row(Map<String, dynamic> r) {
    if (_kind == 'users') {
      final username = (r['username'] ?? '') as String;
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: DiggColors.bgSoft,
          backgroundImage:
              r['profile_image_url'] != null ? NetworkImage(r['profile_image_url'] as String) : null,
        ),
        title: Text(
          (r['display_name'] ?? r['username'] ?? '') as String,
          style: const TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '@$username · ${_formatCount((r['followers_count'] as num?)?.toInt())} followers',
          style: const TextStyle(color: DiggColors.fgSoft),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(client: widget.client, username: username),
          ),
        ),
      );
    }
    if (_kind == 'repos') {
      final repoName = (r['full_name'] ?? r['name'] ?? '') as String;
      final repoUrl = (r['html_url'] ?? r['url'] ?? '').toString();
      return ListTile(
        title: Text(repoName,
            style: const TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700)),
        subtitle: Text(
          '⭐ ${_formatCount((r['stargazers_count'] as num?)?.toInt())} · ${r['description'] ?? ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: DiggColors.fgSoft),
        ),
        onTap: repoName.isEmpty
            ? null
            : () => launchUrl(Uri.parse(
                  repoUrl.isNotEmpty ? repoUrl : 'https://github.com/$repoName',
                )),
      );
    }
    final slug = (r['clusterUrlId'] ?? r['shortId'] ?? '') as String;
    return ListTile(
      title: Text((r['title'] ?? r['headline'] ?? '') as String,
          style: const TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700)),
      subtitle: Text(
        (r['tldr'] ?? r['summary'] ?? '') as String,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: DiggColors.fgSoft),
      ),
      onTap: slug.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => StoryScreen(client: widget.client, slug: slug)),
              ),
    );
  }

  String _formatCount(int? n) {
    if (n == null) return '—';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")}K';
    return '$n';
  }
}
