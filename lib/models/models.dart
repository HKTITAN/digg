// Data classes shared across the app. Kept as plain immutable records with
// fromJson/toJson so they can round-trip through Hive (we store everything
// as Maps in a typeless box and reconstruct on read).

class Story {
  final String slug;
  final int? rank;
  final int? delta;
  final String? title;
  final String? tldr;
  final int? postCount;
  final String? createdAt;
  final List<StoryAuthor> authors;

  // Detail-only (filled when fetched via /ai/{slug})
  final String? headline;
  final String? description;
  final String? summary;
  final String? oneSentence;
  final String? datePublished;
  final String? dateModified;
  final int? commentCount;
  final int? commentsAnalyzedCount;
  final int? distinctCommentAuthorCount;
  final int? snapshotCount;
  final double? confidence;
  final Map<String, dynamic>? totals;
  final Map<String, dynamic>? sentimentPercentages;
  final Map<String, dynamic>? storyWeightedPercentages;
  final Map<String, dynamic>? userWeightedPercentages;
  final Map<String, dynamic>? guardedPercentages;
  final List<String> caveats;
  final List<EngagementSnapshot> snapshots;
  final List<Post> posts;

  const Story({
    required this.slug,
    this.rank,
    this.delta,
    this.title,
    this.tldr,
    this.postCount,
    this.createdAt,
    this.authors = const [],
    this.headline,
    this.description,
    this.summary,
    this.oneSentence,
    this.datePublished,
    this.dateModified,
    this.commentCount,
    this.commentsAnalyzedCount,
    this.distinctCommentAuthorCount,
    this.snapshotCount,
    this.confidence,
    this.totals,
    this.sentimentPercentages,
    this.storyWeightedPercentages,
    this.userWeightedPercentages,
    this.guardedPercentages,
    this.caveats = const [],
    this.snapshots = const [],
    this.posts = const [],
  });

  String get displayTitle => headline ?? title ?? description ?? 'Untitled';
  String get displayTldr => oneSentence ?? tldr ?? summary ?? description ?? '';

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'rank': rank,
        'delta': delta,
        'title': title,
        'tldr': tldr,
        'postCount': postCount,
        'createdAt': createdAt,
        'authors': authors.map((a) => a.toJson()).toList(),
        'headline': headline,
        'description': description,
        'summary': summary,
        'oneSentence': oneSentence,
        'datePublished': datePublished,
        'dateModified': dateModified,
        'commentCount': commentCount,
        'commentsAnalyzedCount': commentsAnalyzedCount,
        'distinctCommentAuthorCount': distinctCommentAuthorCount,
        'snapshotCount': snapshotCount,
        'confidence': confidence,
        'totals': totals,
        'sentimentPercentages': sentimentPercentages,
        'storyWeightedPercentages': storyWeightedPercentages,
        'userWeightedPercentages': userWeightedPercentages,
        'guardedPercentages': guardedPercentages,
        'caveats': caveats,
        'snapshots': snapshots.map((s) => s.toJson()).toList(),
        'posts': posts.map((p) => p.toJson()).toList(),
      };

  factory Story.fromJson(Map j) => Story(
        slug: j['slug'] as String,
        rank: _asInt(j['rank']),
        delta: _asInt(j['delta']),
        title: j['title'] as String?,
        tldr: j['tldr'] as String?,
        postCount: _asInt(j['postCount']),
        createdAt: j['createdAt'] as String?,
        authors: (j['authors'] as List? ?? [])
            .map((a) => StoryAuthor.fromJson(Map<String, dynamic>.from(a as Map)))
            .toList(),
        headline: j['headline'] as String?,
        description: j['description'] as String?,
        summary: j['summary'] as String?,
        oneSentence: j['oneSentence'] as String?,
        datePublished: j['datePublished'] as String?,
        dateModified: j['dateModified'] as String?,
        commentCount: _asInt(j['commentCount']),
        commentsAnalyzedCount: _asInt(j['commentsAnalyzedCount']),
        distinctCommentAuthorCount: _asInt(j['distinctCommentAuthorCount']),
        snapshotCount: _asInt(j['snapshotCount']),
        confidence: _asDouble(j['confidence']),
        totals: j['totals'] is Map ? Map<String, dynamic>.from(j['totals'] as Map) : null,
        sentimentPercentages: j['sentimentPercentages'] is Map
            ? Map<String, dynamic>.from(j['sentimentPercentages'] as Map)
            : null,
        storyWeightedPercentages: j['storyWeightedPercentages'] is Map
            ? Map<String, dynamic>.from(j['storyWeightedPercentages'] as Map)
            : null,
        userWeightedPercentages: j['userWeightedPercentages'] is Map
            ? Map<String, dynamic>.from(j['userWeightedPercentages'] as Map)
            : null,
        guardedPercentages: j['guardedPercentages'] is Map
            ? Map<String, dynamic>.from(j['guardedPercentages'] as Map)
            : null,
        caveats: (j['caveats'] as List? ?? []).whereType<String>().toList(),
        snapshots: (j['snapshots'] as List? ?? [])
            .map((s) => EngagementSnapshot.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
        posts: (j['posts'] as List? ?? [])
            .map((p) => Post.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
      );
}

class StoryAuthor {
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  const StoryAuthor({this.username, this.displayName, this.avatarUrl});
  Map<String, dynamic> toJson() =>
      {'username': username, 'displayName': displayName, 'avatarUrl': avatarUrl};
  factory StoryAuthor.fromJson(Map j) => StoryAuthor(
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
      );
}

class EngagementSnapshot {
  final String bucketStart;
  final int impressionCount;
  final int likeCount;
  final int retweetCount;
  final int replyCount;
  final int bookmarkCount;
  final int quoteCount;
  const EngagementSnapshot({
    required this.bucketStart,
    this.impressionCount = 0,
    this.likeCount = 0,
    this.retweetCount = 0,
    this.replyCount = 0,
    this.bookmarkCount = 0,
    this.quoteCount = 0,
  });
  Map<String, dynamic> toJson() => {
        'bucket_start': bucketStart,
        'impression_count': impressionCount,
        'like_count': likeCount,
        'retweet_count': retweetCount,
        'reply_count': replyCount,
        'bookmark_count': bookmarkCount,
        'quote_count': quoteCount,
      };
  factory EngagementSnapshot.fromJson(Map j) => EngagementSnapshot(
        bucketStart: j['bucket_start'] as String,
        impressionCount: _asInt(j['impression_count']) ?? 0,
        likeCount: _asInt(j['like_count']) ?? 0,
        retweetCount: _asInt(j['retweet_count']) ?? 0,
        replyCount: _asInt(j['reply_count']) ?? 0,
        bookmarkCount: _asInt(j['bookmark_count']) ?? 0,
        quoteCount: _asInt(j['quote_count']) ?? 0,
      );
}

class Post {
  final String? postXId;
  final String? authorUsername;
  final String? authorDisplayName;
  final String? authorCategory;
  final String? authorProfileImageUrl;
  final int? authorRank;
  final String? postType;
  final String? postedAt;
  final String? content;
  final int? likeCount;
  final int? retweetCount;
  final int? replyCount;
  final int? bookmarkCount;

  const Post({
    this.postXId,
    this.authorUsername,
    this.authorDisplayName,
    this.authorCategory,
    this.authorProfileImageUrl,
    this.authorRank,
    this.postType,
    this.postedAt,
    this.content,
    this.likeCount,
    this.retweetCount,
    this.replyCount,
    this.bookmarkCount,
  });

  String? get xUrl => (authorUsername != null && postXId != null)
      ? 'https://x.com/$authorUsername/status/$postXId'
      : null;

  Map<String, dynamic> toJson() => {
        'post_x_id': postXId,
        'author_username': authorUsername,
        'author_display_name': authorDisplayName,
        'author_category': authorCategory,
        'author_profile_image_url': authorProfileImageUrl,
        'author_rank': authorRank,
        'post_type': postType,
        'posted_at': postedAt,
        'content': content,
        'like_count': likeCount,
        'retweet_count': retweetCount,
        'reply_count': replyCount,
        'bookmark_count': bookmarkCount,
      };
  factory Post.fromJson(Map j) => Post(
        postXId: j['post_x_id'] as String?,
        authorUsername: j['author_username'] as String?,
        authorDisplayName: j['author_display_name'] as String?,
        authorCategory: j['author_category'] as String?,
        authorProfileImageUrl: j['author_profile_image_url'] as String?,
        authorRank: _asInt(j['author_rank']),
        postType: j['post_type'] as String?,
        postedAt: j['posted_at'] as String?,
        content: j['content'] as String?,
        likeCount: _asInt(j['like_count']),
        retweetCount: _asInt(j['retweet_count']),
        replyCount: _asInt(j['reply_count']),
        bookmarkCount: _asInt(j['bookmark_count']),
      );
}

class Profile {
  final String username;
  final bool onDigg;
  final String? authorXId;
  final int? tweetCount;
  final String? classification;
  final ProfileCategory? category;
  final String? gravity;
  final String? followers;
  final String? topFollowers;
  final Map<String, double>? vibe;
  final Map<String, double>? topic;
  final String? profileUrl;

  const Profile({
    required this.username,
    required this.onDigg,
    this.authorXId,
    this.tweetCount,
    this.classification,
    this.category,
    this.gravity,
    this.followers,
    this.topFollowers,
    this.vibe,
    this.topic,
    this.profileUrl,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'onDigg': onDigg,
        'authorXId': authorXId,
        'tweetCount': tweetCount,
        'classification': classification,
        'category': category?.toJson(),
        'gravity': gravity,
        'followers': followers,
        'topFollowers': topFollowers,
        'vibe': vibe,
        'topic': topic,
        'profileUrl': profileUrl,
      };
  factory Profile.fromJson(Map j) => Profile(
        username: j['username'] as String,
        onDigg: (j['onDigg'] as bool?) ?? false,
        authorXId: j['authorXId'] as String?,
        tweetCount: _asInt(j['tweetCount']),
        classification: j['classification'] as String?,
        category: j['category'] is Map
            ? ProfileCategory.fromJson(Map<String, dynamic>.from(j['category'] as Map))
            : null,
        gravity: j['gravity'] as String?,
        followers: j['followers'] as String?,
        topFollowers: j['topFollowers'] as String?,
        vibe: _asDoubleMap(j['vibe']),
        topic: _asDoubleMap(j['topic']),
        profileUrl: j['profileUrl'] as String?,
      );
}

class ProfileCategory {
  final String tag;
  final String label;
  const ProfileCategory({required this.tag, required this.label});
  Map<String, dynamic> toJson() => {'tag': tag, 'label': label};
  factory ProfileCategory.fromJson(Map j) =>
      ProfileCategory(tag: j['tag'] as String, label: j['label'] as String);
}

/// One author tile in the homepage `topAuthors` strip or in
/// `/ai/x/rankings`. The same shape works for both surfaces because both
/// pages render from the same Digg author projection.
class AuthorCard {
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? category;
  final int? rank;
  final int? peakRank;
  final int? posLast;
  final int? delta;
  final String? gravity;        // pre-formatted display string (e.g. "9.812")
  final num? composite;         // raw 0..1 score when available
  final Map<String, dynamic>? scoreComponents;

  const AuthorCard({
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.category,
    this.rank,
    this.peakRank,
    this.posLast,
    this.delta,
    this.gravity,
    this.composite,
    this.scoreComponents,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'category': category,
        'rank': rank,
        'peakRank': peakRank,
        'posLast': posLast,
        'delta': delta,
        'gravity': gravity,
        'composite': composite,
        'scoreComponents': scoreComponents,
      };

  factory AuthorCard.fromJson(Map j) => AuthorCard(
        username: (j['username'] ?? '') as String,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        category: j['category'] as String?,
        rank: _asInt(j['rank']),
        peakRank: _asInt(j['peakRank']),
        posLast: _asInt(j['posLast']),
        delta: _asInt(j['delta']),
        gravity: j['gravity'] as String?,
        composite: j['composite'] is num ? j['composite'] as num : null,
        scoreComponents: j['scoreComponents'] is Map
            ? Map<String, dynamic>.from(j['scoreComponents'] as Map)
            : null,
      );
}

/// A GitHub repo tile from `/ai/github/*` or from the homepage's
/// `githubRecentStars` strip.
class RepoCard {
  final String fullName;
  final String? description;
  final int? stargazersCount;
  final int? distinctStarrers;
  final String? mostRecentStarAt;
  final String? topStarrerLogin;
  final String? language;
  final List<AuthorCard> starrers;

  const RepoCard({
    required this.fullName,
    this.description,
    this.stargazersCount,
    this.distinctStarrers,
    this.mostRecentStarAt,
    this.topStarrerLogin,
    this.language,
    this.starrers = const [],
  });

  String get owner => fullName.split('/').first;
  String get name => fullName.split('/').last;
  String get url => 'https://github.com/$fullName';

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'description': description,
        'stargazers_count': stargazersCount,
        'distinct_starrers': distinctStarrers,
        'most_recent_star_at': mostRecentStarAt,
        'top_starrer_login': topStarrerLogin,
        'language': language,
        'starrers': starrers.map((s) => s.toJson()).toList(),
      };

  factory RepoCard.fromJson(Map j) => RepoCard(
        fullName: (j['full_name'] ?? j['name'] ?? '') as String,
        description: j['description'] as String?,
        stargazersCount: _asInt(j['stargazers_count']),
        distinctStarrers: _asInt(j['distinct_starrers']),
        mostRecentStarAt: j['most_recent_star_at'] as String?,
        topStarrerLogin: j['top_starrer_login'] as String?,
        language: j['language'] as String?,
        starrers: ((j['starrers'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => AuthorCard.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

/// A link from one of the homepage's external strips (Hacker News, Techmeme).
class ExternalLink {
  final String title;
  final String url;
  final String? source;
  final String? at;

  const ExternalLink({required this.title, required this.url, this.source, this.at});

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'source': source,
        'at': at,
      };

  factory ExternalLink.fromJson(Map j) => ExternalLink(
        title: (j['title'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        source: j['source'] as String?,
        at: j['at'] as String?,
      );
}

class TrendingStatus {
  final int? storiesToday;
  final int? clustersToday;
  final String? lastFetchCompletedAt;
  const TrendingStatus({this.storiesToday, this.clustersToday, this.lastFetchCompletedAt});
  Map<String, dynamic> toJson() => {
        'storiesToday': storiesToday,
        'clustersToday': clustersToday,
        'lastFetchCompletedAt': lastFetchCompletedAt,
      };
  factory TrendingStatus.fromJson(Map j) => TrendingStatus(
        storiesToday: _asInt(j['storiesToday']),
        clustersToday: _asInt(j['clustersToday']),
        lastFetchCompletedAt: j['lastFetchCompletedAt'] as String?,
      );
}

/// Rich result returned from `DiggClient.getFeed` — not just the story list,
/// but every section the homepage RSC payload ships (top authors, github
/// repos, the hacker-news / techmeme strip, yesterday-tops, up-and-coming).
/// Lives in models.dart instead of client.dart so the parser can produce
/// one without pulling in the HTTP client (circular import otherwise).
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

// ---- helpers ----
int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

Map<String, double>? _asDoubleMap(dynamic v) {
  if (v is! Map) return null;
  final out = <String, double>{};
  v.forEach((k, val) {
    final d = _asDouble(val);
    if (d != null) out[k.toString()] = d;
  });
  return out;
}
