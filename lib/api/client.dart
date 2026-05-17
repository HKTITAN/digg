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

  final http.Client _http;
  final DiggCache cache;

  DiggClient({http.Client? client, required this.cache}) : _http = client ?? http.Client();

  // ----- Trending feed -----
  Future<({List<Story> stories, TrendingStatus status, bool fromCache})> getFeed({
    bool forceRefresh = false,
  }) async {
    const key = 'feed:top';
    if (!forceRefresh) {
      final cached = await cache.read(key);
      if (cached != null) {
        return (
          stories: (cached['stories'] as List).map((j) => Story.fromJson(j as Map)).toList(),
          status: TrendingStatus.fromJson(cached['status'] as Map),
          fromCache: true,
        );
      }
    }
    try {
      final res = await _http.get(Uri.parse('$_origin/ai')).timeout(_timeout);
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final (stories, status) = DiggParser.parseFeed(res.body);
      await cache.write(key, {
        'stories': stories.map((s) => s.toJson()).toList(),
        'status': status.toJson(),
      });
      return (stories: stories, status: status, fromCache: false);
    } catch (e) {
      // Fall back to stale cache so the app still works offline.
      final stale = await cache.read(key, allowStale: true);
      if (stale != null) {
        return (
          stories: (stale['stories'] as List).map((j) => Story.fromJson(j as Map)).toList(),
          status: TrendingStatus.fromJson(stale['status'] as Map),
          fromCache: true,
        );
      }
      rethrow;
    }
  }

  // ----- Single story / cluster -----
  Future<Story> getStory(String slug) async {
    final key = 'story:$slug';
    final cached = await cache.read(key);
    if (cached != null) return Story.fromJson(cached);
    try {
      final res = await _http
          .get(Uri.parse('$_origin/ai/${Uri.encodeComponent(slug)}'))
          .timeout(_timeout);
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

    final res = await _http
        .get(Uri.parse('$_origin/u/x/${Uri.encodeComponent(clean)}'))
        .timeout(_timeout);
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

  // ----- Trending status (small JSON, polled by background worker) -----
  Future<TrendingStatus?> getTrendingStatus() async {
    try {
      final res = await _http
          .get(Uri.parse('$_origin/api/trending/status'))
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      return TrendingStatus.fromJson(jsonDecode(res.body) as Map);
    } catch (_) {
      return null;
    }
  }

  // ----- Search -----
  Future<List<Map<String, dynamic>>> search({
    required String kind,   // 'stories' | 'users' | 'repos'
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
      final url =
          Uri.parse('$_origin/api/search/$kind?q=${Uri.encodeQueryComponent(trimmed)}&limit=$lim');
      final res = await _http.get(url).timeout(_timeout);
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
      if (authors.any((a) => (a['username'] ?? '').toString().toLowerCase() == lower)) {
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

  void close() => _http.close();
}
