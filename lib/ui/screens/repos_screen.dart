import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../layout.dart';
import '../widgets/skeleton.dart';

/// `/ai/github/{kind}` — recent stars, activity, top-starred, new.
class ReposScreen extends StatefulWidget {
  final DiggClient client;
  const ReposScreen({super.key, required this.client});

  @override
  State<ReposScreen> createState() => _ReposScreenState();
}

class _ReposScreenState extends State<ReposScreen> {
  static const _kinds = <(String, String)>[
    ('recent', 'Recent'),
    ('activity', 'Activity'),
    ('stars', 'Stars'),
    ('new', 'New'),
  ];

  String _kind = 'recent';
  List<RepoCard> _repos = const [];
  bool _loading = true;
  String? _error;

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
      final list = await widget.client.getGitHubFeed(_kind);
      if (!mounted) return;
      setState(() {
        _repos = list;
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
      appBar: AppBar(title: const Text('GitHub')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _kinds.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final (slug, label) = _kinds[i];
                final selected = _kind == slug;
                return Center(
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _kind = slug);
                      _load();
                    },
                    selectedColor: DiggColors.greenSoft,
                    backgroundColor: DiggColors.bgSoft,
                    side: BorderSide(
                      color: selected ? DiggColors.green : DiggColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: selected ? DiggColors.green : DiggColors.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _repos.isEmpty) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 16, width: 220, radius: 5),
              SizedBox(height: 8),
              Skeleton(height: 12, width: double.infinity, radius: 4),
              SizedBox(height: 4),
              Skeleton(height: 12, width: 280, radius: 4),
            ],
          ),
        ),
      );
    }
    if (_error != null && _repos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40, color: DiggColors.fgSoft),
              const SizedBox(height: 12),
              const Text('Couldn’t load repos',
                  style: TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_repos.isEmpty) {
      return const Center(
        child: Text('No repos here yet.', style: TextStyle(color: DiggColors.fgSoft)),
      );
    }
    return ListView.separated(
      itemCount: _repos.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: DiggColors.border.withValues(alpha: 0.5)),
      itemBuilder: (_, i) => _RepoRow(repo: _repos[i]),
    );
  }
}

class _RepoRow extends StatelessWidget {
  final RepoCard repo;
  const _RepoRow({required this.repo});

  String _formatCount(int? n) {
    if (n == null) return '—';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactWidth(context);
    return InkWell(
      onTap: () => launchUrl(Uri.parse(repo.url)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 12, compact ? 12 : 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code, color: DiggColors.green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    repo.fullName,
                    style: const TextStyle(
                      color: DiggColors.fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (repo.distinctStarrers != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '+${repo.distinctStarrers} AI-2K',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: DiggColors.green, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            if (repo.description != null && repo.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                repo.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DiggColors.fgSoft,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: DiggColors.metricBookmarks, size: 13),
                const SizedBox(width: 4),
                Text(
                  _formatCount(repo.stargazersCount),
                  style: const TextStyle(
                    color: DiggColors.fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (repo.topStarrerLogin != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('top: @${repo.topStarrerLogin}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: DiggColors.fgSoft, fontSize: 11)),
                  ),
                ],
                if (repo.language != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(repo.language!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: DiggColors.fgSoft, fontSize: 11)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
