import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../layout.dart';
import '../widgets/sparkline.dart';

class StoryScreen extends StatefulWidget {
  final DiggClient client;
  final String slug;
  const StoryScreen({super.key, required this.client, required this.slug});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  Story? _story;
  String? _error;
  bool _loading = true;
  String _sentimentMode = 'sentimentPercentages';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await widget.client.getStory(widget.slug);
      if (!mounted) return;
      setState(() {
        _story = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story'),
        actions: [
          IconButton(
            tooltip: 'Open on digg.com',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(Uri.parse('https://digg.com/ai/${widget.slug}')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DiggColors.green))
          : _story == null
              ? _errorView()
              : _content(_story!),
    );
  }

  Widget _errorView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: DiggColors.fgSoft, size: 40),
              const SizedBox(height: 12),
              Text(
                'Couldn’t load this story',
                style: const TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(color: DiggColors.fgSoft, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _content(Story s) {
    final compact = isCompactWidth(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 12, compact ? 12 : 16, 32),
      children: [
        Text(
          [
            if (s.datePublished != null) _timeAgo(s.datePublished!),
            if (s.postCount != null) '${s.postCount} posts',
            if (s.commentsAnalyzedCount != null) '${s.commentsAnalyzedCount} comments analyzed',
            if (s.confidence != null) '${(s.confidence! * 100).round()}% confidence',
          ].where((x) => x.isNotEmpty).join(' · '),
          style: const TextStyle(
            color: DiggColors.green,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.displayTitle,
          style: TextStyle(
            color: DiggColors.fg,
            fontSize: compact ? 20 : 22,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        if (s.oneSentence != null && s.oneSentence!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: DiggColors.green, width: 3)),
            ),
            child: Text(
              s.oneSentence!,
              style: const TextStyle(color: DiggColors.fg, fontSize: 15, height: 1.45),
            ),
          ),
        ],
        if (s.summary != null && s.summary != s.oneSentence) ...[
          const SizedBox(height: 14),
          Text(
            s.summary!,
            style: const TextStyle(color: DiggColors.fg, fontSize: 15, height: 1.5),
          ),
        ],

        _engagement(s, compact: compact),
        _sentiment(s, compact: compact),
        _caveats(s),
        _posts(s, compact: compact),
      ],
    );
  }

  // ---- Engagement ----
  Widget _engagement(Story s, {required bool compact}) {
    final t = s.totals ?? const {};
    final snaps = s.snapshots;
    if (snaps.isEmpty && (t.isEmpty)) return const SizedBox.shrink();

    final tiles = [
      _MetricTile(
        label: 'VIEWS',
        color: DiggColors.metricViews,
        total: (t['total_impressions'] as num?)?.toInt() ??
            (snaps.isNotEmpty ? snaps.last.impressionCount : null),
        series: snaps.map((x) => x.impressionCount).toList(),
      ),
      _MetricTile(
        label: 'COMMENTS',
        color: DiggColors.metricComments,
        total: (t['total_replies'] as num?)?.toInt() ??
            (snaps.isNotEmpty ? snaps.last.replyCount : null),
        series: snaps.map((x) => x.replyCount).toList(),
      ),
      _MetricTile(
        label: 'REPOSTS',
        color: DiggColors.metricReposts,
        total: (t['total_retweets'] as num?)?.toInt() ??
            (snaps.isNotEmpty ? snaps.last.retweetCount : null),
        series: snaps.map((x) => x.retweetCount).toList(),
      ),
      _MetricTile(
        label: 'BOOKMARKS',
        color: DiggColors.metricBookmarks,
        total: (t['total_bookmarks'] as num?)?.toInt() ??
            (snaps.isNotEmpty ? snaps.last.bookmarkCount : null),
        series: snaps.map((x) => x.bookmarkCount).toList(),
      ),
    ];

    return _section(
      'Cluster engagement',
      aside: s.snapshotCount != null ? '${s.snapshotCount} snapshots' : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useOneColumn = compact || constraints.maxWidth < 420;
          if (useOneColumn) {
            return Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  tiles[i],
                  if (i != tiles.length - 1) const SizedBox(height: 8),
                ],
              ],
            );
          }
          return Column(
            children: [
              Row(children: [
                Expanded(child: tiles[0]),
                const SizedBox(width: 8),
                Expanded(child: tiles[1]),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: tiles[2]),
                const SizedBox(width: 8),
                Expanded(child: tiles[3]),
              ]),
            ],
          );
        },
      ),
    );
  }

  // ---- Sentiment ----
  Widget _sentiment(Story s, {required bool compact}) {
    final modes = <(String, String)>[
      ('sentimentPercentages', 'Raw'),
      ('storyWeightedPercentages', 'Story-weighted'),
      ('userWeightedPercentages', 'User-weighted'),
      ('guardedPercentages', 'Guarded'),
    ].where((m) {
      final p = _percentages(s, m.$1);
      return p != null && p.isNotEmpty;
    }).toList();
    if (modes.isEmpty) return const SizedBox.shrink();

    final active = modes.any((m) => m.$1 == _sentimentMode) ? _sentimentMode : modes.first.$1;
    final p = _percentages(s, active)!;
    final slices = _sentimentSlices(p);
    final pos = slices.positive;
    final neu = slices.neutral;
    final neg = slices.negative;

    return _section(
      'Sentiment',
      aside: s.commentsAnalyzedCount != null
          ? '${s.commentsAnalyzedCount} comments${s.distinctCommentAuthorCount != null ? " · ${s.distinctCommentAuthorCount} authors" : ""}'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in modes)
                ChoiceChip(
                  label: Text(m.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  selected: m.$1 == active,
                  onSelected: (_) => setState(() => _sentimentMode = m.$1),
                  selectedColor: DiggColors.greenSoft,
                  backgroundColor: DiggColors.bgSoft,
                  side: BorderSide(color: m.$1 == active ? DiggColors.green : DiggColors.border),
                  labelStyle: TextStyle(color: m.$1 == active ? DiggColors.green : DiggColors.fg),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(flex: pos, child: Container(color: DiggColors.sentimentPositive)),
                  Expanded(flex: neu, child: Container(color: DiggColors.sentimentNeutral)),
                  Expanded(flex: neg, child: Container(color: DiggColors.sentimentNegative)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              _legend('$pos%', 'positive'),
              _legend('$neu%', 'neutral'),
              _legend('$neg%', 'negative'),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _percentages(Story s, String key) {
    switch (key) {
      case 'sentimentPercentages': return s.sentimentPercentages;
      case 'storyWeightedPercentages': return s.storyWeightedPercentages;
      case 'userWeightedPercentages': return s.userWeightedPercentages;
      case 'guardedPercentages': return s.guardedPercentages;
    }
    return null;
  }

  Widget _legend(String value, String label) => Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$value ',
              style: const TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700, fontSize: 12)),
          TextSpan(text: label, style: const TextStyle(color: DiggColors.fgSoft, fontSize: 12)),
        ]),
      );

  // ---- Caveats ----
  Widget _caveats(Story s) {
    final human = s.caveats.where((c) => c.contains(' ') && c.length > 8).toList();
    if (human.isEmpty) return const SizedBox.shrink();
    return _section(
      'Analysis caveats',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in human.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, size: 5, color: DiggColors.green),
                  ),
                  Expanded(
                    child: Text(
                      c,
                      style: const TextStyle(color: DiggColors.fgSoft, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- Posts ----
  Widget _posts(Story s, {required bool compact}) {
    if (s.posts.isEmpty) return const SizedBox.shrink();
    return _section(
      'Posts in this story',
      aside: '${s.posts.length}',
      child: Column(
        children: [for (final p in s.posts.take(20)) _postCard(p, compact: compact)],
      ),
    );
  }

  Widget _postCard(Post p, {required bool compact}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: DiggColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: DiggColors.bgSoft,
                backgroundImage: p.authorProfileImageUrl != null
                    ? NetworkImage(p.authorProfileImageUrl!)
                    : null,
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.authorDisplayName ?? p.authorUsername ?? '',
                            style: const TextStyle(
                              color: DiggColors.fg,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.authorCategory != null)
                          Flexible(
                            child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: DiggColors.greenSoft,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: DiggColors.greenRing),
                            ),
                            child: Text(
                              p.authorCategory!.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: DiggColors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          ),
                      ],
                    ),
                    Text(
                      [
                        if (p.authorUsername != null) '@${p.authorUsername}',
                        if (p.authorRank != null) '#${p.authorRank}',
                        if (p.postType != null) p.postType,
                        if (p.postedAt != null) _timeAgo(p.postedAt!),
                      ].whereType<String>().join(' · '),
                      style: const TextStyle(color: DiggColors.fgSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.content != null && p.content!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              p.content!,
              style: const TextStyle(color: DiggColors.fg, fontSize: 14, height: 1.4),
            ),
          ],
          if (p.xUrl != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(p.xUrl!)),
              child: const Text('Open on X →',
                  style: TextStyle(color: DiggColors.green, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  // ---- Section helper ----
  Widget _section(String label, {String? aside, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 380;
              if (!compact) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: DiggColors.fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.7,
                      ),
                    ),
                    if (aside != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          aside.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DiggColors.fgSoft,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: DiggColors.fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.7,
                    ),
                  ),
                  if (aside != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      aside.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DiggColors.fgSoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final Color color;
  final int? total;
  final List<int> series;
  const _MetricTile({required this.label, required this.color, this.total, this.series = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: DiggColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
          ),
          const SizedBox(height: 4),
          Text(
            total == null ? '—' : _formatCount(total!),
            style: const TextStyle(color: DiggColors.fg, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (series.length >= 2) Sparkline(values: series, color: color, height: 24),
        ],
      ),
    );
  }
}

({int positive, int neutral, int negative}) _sentimentSlices(Map<String, dynamic> percentages) {
  var pos = (percentages['positive'] as num?)?.toDouble() ?? 0;
  var neg = (percentages['negative'] as num?)?.toDouble() ?? 0;
  var neu = (percentages['neutral'] as num?)?.toDouble();

  // Some payloads may return 0..1 ratios; normalize to 0..100.
  final appearsFractional = pos <= 1.0 && neg <= 1.0 && (neu == null || neu <= 1.0);
  if (appearsFractional) {
    pos *= 100;
    neg *= 100;
    if (neu != null) neu *= 100;
  }

  final rawNeu = neu ?? (100 - pos - neg);
  final clampedPos = pos.clamp(0.0, 100.0);
  final clampedNeg = neg.clamp(0.0, 100.0);
  final clampedNeu = rawNeu.clamp(0.0, 100.0);

  var posInt = clampedPos.round();
  var negInt = clampedNeg.round();
  var neuInt = clampedNeu.round();
  var sum = posInt + negInt + neuInt;

  if (sum > 100 && sum > 0) {
    posInt = ((posInt / sum) * 100).round();
    negInt = ((negInt / sum) * 100).round();
    neuInt = ((neuInt / sum) * 100).round();
    sum = posInt + negInt + neuInt;
  }

  if (sum != 100) {
    neuInt += (100 - sum);
  }
  neuInt = neuInt.clamp(0, 100);
  return (
    positive: posInt.clamp(0, 100),
    neutral: neuInt.clamp(0, 100),
    negative: negInt.clamp(0, 100),
  );
}

String _formatCount(num n) {
  if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")}M';
  if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")}K';
  return '$n';
}

String _timeAgo(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final diff = DateTime.now().toUtc().difference(t.toUtc());
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
