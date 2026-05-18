import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../layout.dart';
import '../widgets/skeleton.dart';
import 'profile_screen.dart';

/// Full ranked-author list — surfaces the `/ai/x/rankings` page, with a
/// horizontal chip strip to filter by Digg category (Founder, Researcher,
/// Investor, …).
class RankingsScreen extends StatefulWidget {
  final DiggClient client;
  const RankingsScreen({super.key, required this.client});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  static const _tags = <(String, String)>[
    ('all', 'All'),
    ('researcher', 'Researcher'),
    ('research-engineer', 'Research Engineer'),
    ('engineer', 'Engineer'),
    ('founder', 'Founder'),
    ('investor', 'Investor'),
    ('executive', 'Executive'),
    ('creator', 'Creator'),
    ('company', 'Company'),
    ('academic', 'Academic'),
    ('ai-safety', 'AI Safety'),
    ('open-source', 'Open Source'),
    ('policy', 'Policy'),
    ('politician', 'Politician'),
  ];

  String _tag = 'all';
  List<AuthorCard> _authors = const [];
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
      final list = await widget.client.getRankings(tag: _tag == 'all' ? null : _tag);
      if (!mounted) return;
      setState(() {
        _authors = list;
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
      appBar: AppBar(title: const Text('Rankings')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _tags.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final (slug, label) = _tags[i];
                final selected = _tag == slug;
                return Center(
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _tag = slug);
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
    if (_loading && _authors.isEmpty) {
      return ListView.builder(
        itemCount: 12,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Skeleton(width: 28, height: 12, radius: 4),
              SizedBox(width: 14),
              Skeleton(width: 40, height: 40, radius: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 14, width: 160, radius: 4),
                    SizedBox(height: 6),
                    Skeleton(height: 11, width: 90, radius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null && _authors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40, color: DiggColors.fgSoft),
              const SizedBox(height: 12),
              const Text('Couldn’t load rankings',
                  style: TextStyle(color: DiggColors.fg, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_authors.isEmpty) {
      return const Center(
        child: Text('No ranked authors here yet.',
            style: TextStyle(color: DiggColors.fgSoft)),
      );
    }
    return ListView.separated(
      itemCount: _authors.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: DiggColors.border),
      itemBuilder: (_, i) => _AuthorRow(
        author: _authors[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              client: widget.client,
              username: _authors[i].username,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final AuthorCard author;
  final VoidCallback onTap;
  const _AuthorRow({required this.author, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                author.rank != null ? '#${author.rank}' : '—',
                style: const TextStyle(
                  color: DiggColors.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: DiggColors.bgSoft,
              backgroundImage:
                  author.avatarUrl != null ? NetworkImage(author.avatarUrl!) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          author.displayName ?? author.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DiggColors.fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (author.category != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: DiggColors.greenSoft,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: DiggColors.greenRing),
                            ),
                            child: Text(
                              author.category!.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: DiggColors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: isNarrowWidth(context) ? 9 : 10,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${author.username}'
                    '${author.gravity != null ? "  ·  ${author.gravity} gravity" : ""}',
                    style: const TextStyle(color: DiggColors.fgSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DiggColors.fgSoft, size: 18),
          ],
        ),
      ),
    );
  }
}
