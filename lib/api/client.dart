// HTTP client for digg.com. All public endpoints; no auth. Reverse-engineered
// surface — see github.com/HKTITAN/DIGGforX for the documented endpoints.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../storage/cache.dart';
import 'parser.dart';

class DiggClient {
  static const _origin = 'https://digg.com';
  static const _timeout = Duration(seconds: 15);

  // Pose as a normal desktop browser. Dart's default User-Agent is
  // `Dart/<version> (dart:io)`, and digg.com appears to serve a stripped
  // (or 403) response to it — that was the cause of the blank home
  // screen in v0.1.3 / v0.1.4. The browser extension never hit this
  // because Chrome supplies its own UA.
  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Cache-Control': 'no-cache',
  };

  final http.Client _http;
  final DiggCache cache;

  DiggClient({http.Client? client, required this.cache})
      : _http = client ?? http.Client();

  Future<http.Response> _get(String path) => _http
      .get(Uri.parse('$_origin$path'), headers: _browserHeaders)
      .timeout(_timeout);

  // ----- Trending feed (with rich homepage sections) -----

  Future<FeedResult> getFeed({bool forceRefresh = false}) async {
    const key = 'feed:rich';
    if (!forceRefresh) {
      final cached = await cache.read(key);
      if (cached != null) {
        return FeedResult.fromJson(cached, fromCache: true);
      }
    }
    try {
      final res = await _get('/ai');
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final feed = DiggParser.parseRichFeed(res.body);
      await cache.write(key, feed.toJson());
      return feed.copyWith(fromCache: false);
    } catch (e) {
      final stale = await cache.read(key, allowStale: true);
      if (stale != null) return FeedResult.fromJson(stale, fromCache: true);
      rethrow;
    }
  }

  // ----- Single story / cluster -----

  Future<Story> getStory(String slug) async {
    final key = 'story:$slug';
    final cached = await cache.read(key);
    if (cached != null) return Story.fromJson(cached);
    try {
      final res = await _get('/ai/${Uri.encodeComponent(slug)}');
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final story = DiggParser.parseStory(slug, res.body);
      await cache.write(key, story.toJson());
      return story;
    } catch (e) {
      final stale = await cache.read(key, allowStale: true);
      if (stale != null) return Story.fromJson(stale);
      rethrow;
    }
  }

  // ----- Profile (@handle on X) -----

  Future<Profile> getProfile(String username) async {
    final clean = username.replaceAll(RegExp(r'^@'), '').trim();
    final key = 'profile:${clean.toLowerCase()}';
    final cached = await cache.read(key);
    if (cached != null) return Profile.fromJson(cached);

    final res = await _get('/u/x/${Uri.encodeComponent(clean)}');
    if (res.statusCode == 404) {
      final p = Profile(username: clean, onDigg: false);
      await cache.write(key, p.toJson());
      return p;
    }
    if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
    final profile = DiggParser.parseProfile(clean, res.body);
    await cache.write(key, profile.toJson());
    return profile;
  }

  // ----- Trending status (small JSON) -----

  Future<TrendingStatus?> getTrendingStatus() async {
    try {
      final res = await _get('/api/trending/status');
      if (res.statusCode != 200) return null;
      return TrendingStatus.fromJson(jsonDecode(res.body) as Map);
    } catch (_) {
      return null;
    }
  }

  // ----- Search -----

  Future<List<Map<String, dynamic>>> search({
    required String kind, // 'stories' | 'users' | 'repos'
    required String q,
    int? limit,
  }) async {
    final trimmed = q.trim();
    if (trimmed.length < 2) return [];
    final lim = limit ?? (kind == 'users' ? 12 : 8);
    final key = 'search:$kind:${trimmed.toLowerCase()}:$lim';
    final cached = await cache.read(key);
    if (cached != null) {
      return (cached['results'] as List).cast<Map<String, dynamic>>();
    }
    try {
      final res = await _get(
        '/api/search/$kind?q=${Uri.encodeQueryComponent(trimmed)}&limit=$lim',
      );
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map;
      final results = ((json['results'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      await cache.write(key, {'results': results});
      return results;
    } catch (_) {
      final stale = await cache.read(key, allowStale: true);
      if (stale != null) {
        return (stale['results'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    }
  }

  // ----- Stories featuring a given user (search + filter) -----

  Future<List<Story>> getStoriesFeaturing(String handle) async {
    final results = await search(kind: 'stories', q: handle, limit: 8);
    final lower = handle.toLowerCase();
    final stories = <Story>[];
    for (final r in results) {
      final authors = (r['authors'] as List? ?? []).whereType<Map>();
      if (authors.any(
          (a) => (a['username'] ?? '').toString().toLowerCase() == lower)) {
        try {
          stories.add(Story(
            slug: (r['clusterUrlId'] ?? r['shortId'] ?? '') as String,
            title: r['title'] as String?,
            tldr: r['tldr'] as String?,
            rank: r['rank'] is int ? r['rank'] as int : null,
            postCount: r['postCount'] is int ? r['postCount'] as int : null,
            createdAt: r['createdAt'] as String?,
            authors: authors
                .map((a) => StoryAuthor(
                      username: a['username'] as String?,
                      displayName: a['displayName'] as String?,
                      avatarUrl: a['avatarUrl'] as String?,
                    ))
                .toList(),
          ));
        } catch (_) {}
      }
    }
    return stories;
  }

  // ----- GitHub feeds: /ai/github/{recent|activity|stars|new} -----

  Future<List<RepoCard>> getGitHubFeed(String kind) async {
    // kind ∈ { 'recent', 'activity', 'stars', 'new' }
    final key = 'github:$kind';
    final cached = await cache.read(key);
    if (cached != null) {
      return ((cached['repos'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => RepoCard.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    try {
      final res = await _get('/ai/github/$kind');
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final repos = DiggParser.parseGitHubFeed(res.body);
      await cache.write(key, {'repos': repos.map((r) => r.toJson()).toList()});
      return repos;
    } catch (e) {
      final stale = await cache.read(key, allowStale: true);
      if (stale != null) {
        return ((stale['repos'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => RepoCard.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    }
  }

  // ----- Rankings: /ai/x/rankings[?tag=...] -----

  Future<List<AuthorCard>> getRankings({String? tag}) async {
    final t = tag ?? 'all';
    final key = 'rankings:$t';
    final cached = await cache.read(key);
    if (cached != null) {
      return ((cached['authors'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => AuthorCard.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    try {
      final path = tag == null || tag == 'all'
          ? '/ai/x/rankings'
          : '/ai/x/rankings?tag=$tag';
      final res = await _get(path);
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final authors = DiggParser.parseRankings(res.body);
      await cache.write(
          key, {'authors': authors.map((a) => a.toJson()).toList()});
      return authors;
    } catch (e) {
      final stale = await cache.read(key, allowStale: true);
      if (stale != null) {
        return ((stale['authors'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => AuthorCard.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
      return const [];
    }
  }

  void close() => _http.close();
}

/// Rich result returned from `getFeed` — not just the story list, but every
/// section the homepage RSC payload ships (top authors, github repos, the
/// hacker-news / techmeme strip, yesterday-tops, up-and-coming).
class FeedResult {
  final List<Story> stories;
  final TrendingStatus status;
  final bool fromCache;
  final List<AuthorCard> topAuthors;
  final List<RepoCard> githubRecentStars;
  final List<Story> upAndComing;
  final List<Story> yesterdayTop;
  final List<ExternalLink> hackerNews;
  final List<ExternalLink> techmeme;

  const FeedResult({
    required this.stories,
    required this.status,
    this.fromCache = false,
    this.topAuthors = const [],
    this.githubRecentStars = const [],
    this.upAndComing = const [],
    this.yesterdayTop = const [],
    this.hackerNews = const [],
    this.techmeme = const [],
  });

  FeedResult copyWith({bool? fromCache}) => FeedResult(
        stories: stories,
        status: status,
        fromCache: fromCache ?? this.fromCache,
        topAuthors: topAuthors,
        githubRecentStars: githubRecentStars,
        upAndComing: upAndComing,
        yesterdayTop: yesterdayTop,
        hackerNews: hackerNews,
        techmeme: techmeme,
      );

  Map<String, dynamic> toJson() => {
        'stories': stories.map((s) => s.toJson()).toList(),
        'status': status.toJson(),
        'topAuthors': topAuthors.map((a) => a.toJson()).toList(),
        'githubRecentStars': githubRecentStars.map((r) => r.toJson()).toList(),
        'upAndComing': upAndComing.map((s) => s.toJson()).toList(),
        'yesterdayTop': yesterdayTop.map((s) => s.toJson()).toList(),
        'hackerNews': hackerNews.map((l) => l.toJson()).toList(),
        'techmeme': techmeme.map((l) => l.toJson()).toList(),
      };

  factory FeedResult.fromJson(Map j, {required bool fromCache}) => FeedResult(
        stories: ((j['stories'] as List?) ?? const [])
            .map((m) => Story.fromJson(m as Map))
            .toList(),
        status: TrendingStatus.fromJson((j['status'] as Map?) ?? const {}),
        fromCache: fromCache,
        topAuthors: ((j['topAuthors'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => AuthorCard.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        githubRecentStars: ((j['githubRecentStars'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => RepoCard.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        upAndComing: ((j['upAndComing'] as List?) ?? const [])
            .map((m) => Story.fromJson(m as Map))
            .toList(),
        yesterdayTop: ((j['yesterdayTop'] as List?) ?? const [])
            .map((m) => Story.fromJson(m as Map))
            .toList(),
        hackerNews: ((j['hackerNews'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => ExternalLink.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        techmeme: ((j['techmeme'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => ExternalLink.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}
