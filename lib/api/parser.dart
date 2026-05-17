// HTML/RSC parsing for digg.com pages. Ported from the browser-extension
// background worker — same shapes, same fallback chain.
//
//   Primary source for headline/description/dates: schema.org JSON-LD block
//   Secondary: React Server Components stream (self.__next_f.push([1, "..."]))
//   Tertiary: <meta og:*> + <title>
//   Post content + post_type: server-rendered HTML scanned around each
//   x.com/{handle}/status/{id} link.

import 'dart:convert';

import '../models/models.dart';

class DiggParser {
  // ========== Flight stream ==========

  /// Pull every `self.__next_f.push([1, "..."])` chunk out of the page and
  /// concatenate the decoded contents.
  ///
  /// We *don't* use a regex here. A regex like `"((?:\\.|[^"\\])*)"` looks
  /// innocent but Dart's RegExp engine blows its matcher stack on big
  /// pages (digg's profile HTML is ~370 KB) — and on Windows, where the
  /// default native stack is much smaller than Android's, it surfaces as
  /// the `StackOverflowError` ("Stack Overflow") we kept getting in the
  /// "Couldn't reach digg.com" path. Hand-rolling the scan is faster and
  /// uses constant stack.
  static String extractFlightText(String html) {
    const prefix = 'self.__next_f.push([1,"';
    final buf = StringBuffer();
    var i = 0;
    while (true) {
      final start = html.indexOf(prefix, i);
      if (start < 0) break;
      // Walk forward from the opening quote, jumping past `\X` escapes,
      // until we hit the closing unescaped quote.
      var p = start + prefix.length;
      while (p < html.length) {
        final c = html.codeUnitAt(p);
        if (c == 0x5C) {            // backslash → skip the escape pair
          p += 2;
          continue;
        }
        if (c == 0x22) break;       // unescaped quote → end of chunk
        p++;
      }
      if (p >= html.length) break;
      final raw = html.substring(start + prefix.length, p);
      try {
        // Reuse JSON's string decoding (handles \", \\, \n, \uXXXX, …).
        final decoded = jsonDecode('"$raw"');
        if (decoded is String) buf.write(decoded);
      } catch (_) {
        // Malformed chunk — drop it and keep going.
      }
      i = p + 1;
    }
    return buf.toString();
  }

  static String? stringAfter(String text, String key) {
    final re = RegExp('"$key"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"');
    final m = re.firstMatch(text);
    if (m == null) return null;
    try {
      return jsonDecode('"${m.group(1)}"') as String;
    } catch (_) {
      return null;
    }
  }

  static num? numberAfter(String text, String key) {
    final re = RegExp('"$key"\\s*:\\s*"?(-?[0-9.]+)"?');
    final m = re.firstMatch(text);
    if (m == null) return null;
    return num.tryParse(m.group(1)!);
  }

  static int? intAfter(String text, String key) => numberAfter(text, key)?.toInt();
  static double? doubleAfter(String text, String key) => numberAfter(text, key)?.toDouble();

  /// Read the first JSON object whose key is [key]. Walks the brace-depth so
  /// nested braces inside string values don't confuse us.
  static Map<String, dynamic>? objectAfter(String text, String key) {
    final idx = text.indexOf('"$key":');
    if (idx < 0) return null;
    final braceStart = text.indexOf('{', idx + key.length + 3);
    if (braceStart < 0) return null;
    final between = text.substring(idx + key.length + 3, braceStart);
    if (RegExp(r'[,}\]]').hasMatch(between)) return null;
    final end = _matchClose(text, braceStart, '{', '}');
    if (end < 0) return null;
    try {
      final obj = jsonDecode(text.substring(braceStart, end + 1));
      return obj is Map ? Map<String, dynamic>.from(obj) : null;
    } catch (_) {
      return null;
    }
  }

  /// Same but for array values.
  static List<dynamic>? arrayAfter(String text, String key) {
    final idx = text.indexOf('"$key":');
    if (idx < 0) return null;
    final bracketStart = text.indexOf('[', idx + key.length + 3);
    if (bracketStart < 0) return null;
    final between = text.substring(idx + key.length + 3, bracketStart);
    if (RegExp(r'[,}\]]').hasMatch(between)) return null;
    final end = _matchClose(text, bracketStart, '[', ']');
    if (end < 0) return null;
    try {
      final arr = jsonDecode(text.substring(bracketStart, end + 1));
      return arr is List ? arr : null;
    } catch (_) {
      return null;
    }
  }

  static int _matchClose(String text, int start, String open, String close) {
    var depth = 0;
    var inStr = false;
    var esc = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == r'\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
      } else {
        if (c == '"') {
          inStr = true;
        } else if (c == open) {
          depth++;
        } else if (c == close) {
          depth--;
          if (depth == 0) return i;
        }
      }
    }
    return -1;
  }

  // ========== JSON-LD (NewsArticle, structured data) ==========

  static Map<String, dynamic>? extractJsonLd(String html) {
    // Match both quote styles for the `type=` attribute, but keep the
    // pattern simple — Dart's adjacent-string concatenation around `["']`
    // produced an invalid regex (FormatException: Unmatched ')'), so we
    // just OR two literal forms.
    final re = RegExp(
      r'<script\b[^>]*type=(?:"application/ld\+json"|' r"'application/ld\+json'" r')[^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    );
    Map<String, dynamic>? fallback;
    for (final m in re.allMatches(html)) {
      try {
        final raw = jsonDecode(m.group(1)!);
        // ld+json can be a single object or an array; we want the NewsArticle.
        final obj = raw is List
            ? raw.firstWhere((x) => x is Map && x['@type'] == 'NewsArticle', orElse: () => raw.first)
            : raw;
        if (obj is Map && obj['@type'] == 'NewsArticle') {
          return Map<String, dynamic>.from(obj);
        }
        if (obj is Map && obj['headline'] != null && fallback == null) {
          fallback = Map<String, dynamic>.from(obj);
        }
      } catch (_) {}
    }
    return fallback;
  }

  static String? metaContent(String html, String prop) {
    // digg.com renders `<meta property="og:title" content="...">` with
    // double quotes only; matching just that is enough and keeps the
    // regex simple (mixing quote chars in a Dart pattern is what blew
    // up `Couldn't load this story` with FormatException previously).
    final esc = RegExp.escape(prop);
    final re = RegExp(
      '<meta[^>]+property="$esc"[^>]+content="([^"]+)"',
      caseSensitive: false,
    );
    final m = re.firstMatch(html);
    return m == null ? null : _decodeEntities(m.group(1)!);
  }

  static String? titleTag(String html) {
    final m = RegExp(r'<title>([^<]+)</title>', caseSensitive: false).firstMatch(html);
    return m == null ? null : _decodeEntities(m.group(1)!);
  }

  static String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');

  static String _stripDiggSuffix(String? s) {
    if (s == null) return '';
    return s.replaceFirst(RegExp(r'\s*[·•]\s*Digg\s*$'), '').trim();
  }

  // ========== Story / cluster ==========

  static Story parseStory(String slug, String html) {
    final ld = extractJsonLd(html);
    String flight = '';
    try {
      flight = extractFlightText(html);
    } catch (_) {}

    final headline = (ld != null ? _stripDiggSuffix(ld['headline'] as String?) : '')
        .ifEmpty(stringAfter(flight, 'headline'))
        .ifEmpty(_stripDiggSuffix(metaContent(html, 'og:title') ?? titleTag(html)));
    final description = ld?['description'] as String? ?? metaContent(html, 'og:description');

    final snaps = arrayAfter(flight, 'snapshots');
    final List<EngagementSnapshot> snapshots = snaps == null
        ? const []
        : (snaps.whereType<Map>().map((m) {
              try {
                return EngagementSnapshot.fromJson(Map<String, dynamic>.from(m));
              } catch (_) {
                return null;
              }
            }).whereType<EngagementSnapshot>().toList()
              ..sort((a, b) => a.bucketStart.compareTo(b.bucketStart)));

    // Posts from RSC stream
    final posts = <Post>[..._extractPostsFromFlight(flight)];

    // Author fallback from JSON-LD when RSC has no posts
    if (posts.isEmpty && ld != null && ld['author'] is List) {
      for (final a in (ld['author'] as List).whereType<Map>()) {
        final handle = _xHandleFromAuthor(a);
        if (handle != null) {
          posts.add(Post(authorUsername: handle, authorDisplayName: a['name'] as String?));
        }
      }
    }

    // Merge in rendered post content from the HTML.
    final renderedById = _extractRenderedPosts(html);
    final renderedByHandle = <String, _RenderedPost>{};
    for (final r in renderedById.values) {
      renderedByHandle.putIfAbsent(r.handle.toLowerCase(), () => r);
    }

    final merged = <Post>[];
    final seenIds = <String>{};
    for (final p in posts) {
      final r = (p.postXId != null ? renderedById[p.postXId] : null) ??
          (p.authorUsername != null ? renderedByHandle[p.authorUsername!.toLowerCase()] : null);
      merged.add(Post(
        postXId: p.postXId ?? r?.id,
        authorUsername: p.authorUsername ?? r?.handle,
        authorDisplayName: p.authorDisplayName,
        authorCategory: p.authorCategory,
        authorProfileImageUrl: p.authorProfileImageUrl,
        authorRank: p.authorRank,
        postType: p.postType ?? r?.postType,
        postedAt: p.postedAt,
        content: p.content ?? r?.content,
        likeCount: p.likeCount,
        retweetCount: p.retweetCount,
        replyCount: p.replyCount,
        bookmarkCount: p.bookmarkCount,
      ));
      if (p.postXId != null) seenIds.add(p.postXId!);
    }
    // Add any HTML-only posts not present in the RSC stream.
    for (final r in renderedById.values) {
      if (seenIds.contains(r.id)) continue;
      merged.add(Post(
        postXId: r.id,
        authorUsername: r.handle,
        content: r.content,
        postType: r.postType,
      ));
    }

    return Story(
      slug: slug,
      headline: headline.isEmpty ? null : headline,
      description: description,
      summary: stringAfter(flight, 'summary') ?? description,
      oneSentence: stringAfter(flight, 'oneSentence') ??
          stringAfter(flight, 'one_sentence') ??
          stringAfter(flight, 'tldr') ??
          stringAfter(flight, 'classification_tldr'),
      datePublished: (ld?['datePublished'] as String?) ?? stringAfter(flight, 'datePublished'),
      dateModified: (ld?['dateModified'] as String?) ?? stringAfter(flight, 'dateModified'),
      postCount: intAfter(flight, 'postCount') ?? intAfter(flight, 'sourcePostCount'),
      commentCount: intAfter(flight, 'commentCount'),
      commentsAnalyzedCount: intAfter(flight, 'commentsAnalyzedCount'),
      distinctCommentAuthorCount: intAfter(flight, 'distinctCommentAuthorCount'),
      snapshotCount: intAfter(flight, 'snapshotCount'),
      confidence: doubleAfter(flight, 'confidence'),
      totals: objectAfter(flight, 'totals'),
      sentimentPercentages: objectAfter(flight, 'sentimentPercentages'),
      storyWeightedPercentages: objectAfter(flight, 'storyWeightedPercentages'),
      userWeightedPercentages: objectAfter(flight, 'userWeightedPercentages'),
      guardedPercentages: objectAfter(flight, 'guardedPercentages'),
      caveats: ((arrayAfter(flight, 'caveats') ?? const []).whereType<String>().toList()),
      snapshots: snapshots,
      posts: merged,
    );
  }

  static Iterable<Post> _extractPostsFromFlight(String text) sync* {
    final seen = <String>{};
    final re = RegExp(r'"post_x_id":"([^"]+)"');
    for (final m in re.allMatches(text)) {
      final id = m.group(1)!;
      if (seen.contains(id)) continue;
      // Walk back to find the enclosing `{`.
      var depth = 0;
      var i = m.start;
      while (i > 0) {
        final c = text[i];
        if (c == '}') depth++;
        else if (c == '{') {
          if (depth == 0) break;
          depth--;
        }
        i--;
      }
      if (text[i] != '{') continue;
      final end = _matchClose(text, i, '{', '}');
      if (end < 0) continue;
      try {
        final obj = jsonDecode(text.substring(i, end + 1));
        if (obj is Map && obj['post_x_id'] != null) {
          seen.add(id);
          yield Post.fromJson(Map<String, dynamic>.from(obj));
        }
      } catch (_) {}
      if (seen.length > 40) break;
    }
  }

  static String? _xHandleFromAuthor(Map a) {
    final same = a['sameAs'];
    final urls = same is List ? same : (same is String ? [same] : const []);
    for (final u in urls) {
      final m = RegExp(r'(?:x|twitter)\.com\/([A-Za-z0-9_]{1,15})').firstMatch(u.toString());
      if (m != null) return m.group(1);
    }
    return null;
  }

  // ----- Rendered posts (HTML scan for content/post_type) -----

  static Map<String, _RenderedPost> _extractRenderedPosts(String html) {
    final out = <String, _RenderedPost>{};
    final statusRe = RegExp(
        r'https?:\/\/(?:x|twitter)\.com\/([A-Za-z0-9_]{1,15})\/status\/(\d+)');
    final hits = statusRe.allMatches(html).toList();
    for (var i = 0; i < hits.length; i++) {
      final m = hits[i];
      final handle = m.group(1)!;
      final id = m.group(2)!;
      if (out.containsKey(id)) continue;
      final endIdx = i + 1 < hits.length ? hits[i + 1].start : html.length;
      final sliceEnd = (m.end + 8000).clamp(0, endIdx);
      final slice = html.substring(m.end, sliceEnd);
      final content = _extractWhitespacePreParagraphs(slice);
      if (content.isEmpty) continue;
      out[id] = _RenderedPost(
        id: id,
        handle: handle,
        content: content,
        postType: _detectPostType(slice),
      );
    }
    return out;
  }

  static String _extractWhitespacePreParagraphs(String slice) {
    final re = RegExp(
        r'<p\b[^>]*class="[^"]*whitespace-pre-wrap[^"]*"[^>]*>([\s\S]*?)<\/p>');
    final parts = <String>[];
    for (final m in re.allMatches(slice)) {
      final txt = _stripTagsDecode(m.group(1)!).trim();
      if (txt.isNotEmpty) parts.add(txt);
      if (parts.length >= 6) break;
    }
    return parts.join('\n\n');
  }

  static String _stripTagsDecode(String s) => _decodeEntities(
      s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'<[^>]+>'), ''));

  static String? _detectPostType(String slice) {
    final m = RegExp(r'(QUOTE POST|REPLY|RETWEET|ORIGINAL)').firstMatch(slice);
    if (m == null) return null;
    return m.group(1)!.toLowerCase().replaceAll(' post', '');
  }

  // ========== Profile ==========

  static Profile parseProfile(String username, String html) {
    String flight = '';
    try {
      flight = extractFlightText(html);
    } catch (_) {}

    final vibe = _asDoubleMap(objectAfter(flight, 'vibeDistribution'));
    final topic = _asDoubleMap(objectAfter(flight, 'topicDistribution'));
    final tweetCount = intAfter(flight, 'tweetCount');
    final authorXId = stringAfter(flight, 'authorXId');
    final classification = _classificationFromHtml(html);
    final category = _categoryFromHtml(html);
    final stats = _headerStats(html);

    final onDigg = vibe != null ||
        topic != null ||
        classification != null ||
        category != null ||
        stats['gravity'] != null;

    return Profile(
      username: username,
      onDigg: onDigg,
      authorXId: authorXId,
      tweetCount: tweetCount,
      classification: classification,
      category: category,
      gravity: stats['gravity'],
      followers: stats['followers'],
      topFollowers: stats['topFollowers'],
      vibe: vibe,
      topic: topic,
      profileUrl: 'https://digg.com/u/x/$username',
    );
  }

  static String? _classificationFromHtml(String html) {
    final m = RegExp(r'AI Classification</legend>\s*<p[^>]*>([\s\S]*?)</p>').firstMatch(html);
    if (m == null) return null;
    return _decodeEntities(m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '')).trim();
  }

  static ProfileCategory? _categoryFromHtml(String html) {
    final m =
        RegExp(r'rankings\?tag=([a-z-]+)"[^>]*title="View ([^"]+) rankings').firstMatch(html);
    if (m == null) return null;
    return ProfileCategory(tag: m.group(1)!, label: m.group(2)!);
  }

  static Map<String, String?> _headerStats(String html) {
    final result = <String, String?>{'gravity': null, 'followers': null, 'topFollowers': null};
    final re = RegExp(
        r'<span class="font-bold text-foreground">([^<]+)</span>\s*(?:<!--[^>]*-->\s*)*([A-Z][A-Z ]+)');
    for (final m in re.allMatches(html)) {
      final value = m.group(1)!.trim();
      final label = m.group(2)!.trim();
      if (label.startsWith('TOP FOLLOWERS')) result['topFollowers'] = value;
      else if (label.startsWith('GRAVITY')) result['gravity'] = value;
      else if (label.startsWith('FOLLOWERS')) result['followers'] = value;
    }
    return result;
  }

  static Map<String, double>? _asDoubleMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final out = <String, double>{};
    m.forEach((k, v) {
      if (v is num) out[k] = v.toDouble();
      else if (v is String) {
        final d = double.tryParse(v);
        if (d != null) out[k] = d;
      }
    });
    return out;
  }

  // ========== Feed ==========

  static (List<Story>, TrendingStatus) parseFeed(String html) {
    final flight = extractFlightText(html);
    final stories = <Story>[];

    final anchor = flight.indexOf('"storiesByFilter"');
    if (anchor >= 0) {
      final itemsAt = flight.indexOf('"items":[', anchor);
      if (itemsAt >= 0) {
        var i = itemsAt + '"items":['.length;
        while (i < flight.length && flight[i] != ']') {
          while (
              i < flight.length && (flight[i] == ',' || flight[i] == ' ' || flight[i] == '\n')) {
            i++;
          }
          if (i >= flight.length || flight[i] != '{') break;
          final end = _matchClose(flight, i, '{', '}');
          if (end < 0) break;
          try {
            final obj = jsonDecode(flight.substring(i, end + 1));
            if (obj is Map) {
              stories.add(_storyFromFeedItem(Map<String, dynamic>.from(obj)));
            }
          } catch (_) {}
          i = end + 1;
          if (stories.length >= 60) break;
        }
      }
    }

    final status = TrendingStatus(
      storiesToday: intAfter(flight, 'storiesToday'),
      clustersToday: intAfter(flight, 'clustersToday'),
      lastFetchCompletedAt: stringAfter(flight, 'lastFetchCompletedAt'),
    );

    return (stories, status);
  }

  static Story _storyFromFeedItem(Map<String, dynamic> j) {
    final authors = (j['authors'] as List? ?? [])
        .whereType<Map>()
        .map((a) => StoryAuthor(
              username: a['username'] as String?,
              displayName: a['displayName'] as String?,
              avatarUrl: a['avatarUrl'] as String?,
            ))
        .toList();
    return Story(
      slug: (j['clusterUrlId'] ?? j['shortId'] ?? '') as String,
      rank: j['rank'] is int ? j['rank'] as int : null,
      delta: j['delta'] is int ? j['delta'] as int : null,
      title: j['title'] as String?,
      tldr: j['tldr'] as String?,
      postCount: j['postCount'] is int ? j['postCount'] as int : null,
      createdAt: j['createdAt'] as String?,
      authors: authors,
    );
  }
}

class _RenderedPost {
  final String id;
  final String handle;
  final String content;
  final String? postType;
  _RenderedPost({required this.id, required this.handle, required this.content, this.postType});
}

extension on String {
  String ifEmpty(String? other) => isEmpty ? (other ?? '') : this;
}
