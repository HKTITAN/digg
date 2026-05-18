import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';

class RepoStrip extends StatelessWidget {
  final List<RepoCard> repos;
  final void Function(RepoCard) onTap;
  final double height;

  const RepoStrip({
    super.key,
    required this.repos,
    required this.onTap,
    this.height = 152,
  });

  @override
  Widget build(BuildContext context) {
    if (repos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: repos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _Tile(repo: repos[i], onTap: () => onTap(repos[i])),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final RepoCard repo;
  final VoidCallback onTap;
  const _Tile({required this.repo, required this.onTap});

  String _formatCount(int? n) {
    if (n == null) return '—';
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: DiggColors.border),
          borderRadius: BorderRadius.circular(14),
          color: DiggColors.bgSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: DiggColors.bgRaised,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.code, size: 13, color: DiggColors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    repo.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DiggColors.fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (repo.description != null)
              Expanded(
                child: Text(
                  repo.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DiggColors.fgSoft,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              )
            else
              const Spacer(),
            Row(
              children: [
                const Icon(Icons.star, size: 12, color: DiggColors.metricBookmarks),
                const SizedBox(width: 4),
                Text(
                  _formatCount(repo.stargazersCount),
                  style: const TextStyle(
                    color: DiggColors.fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (repo.distinctStarrers != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '·  ${repo.distinctStarrers} AI-2K',
                    style: const TextStyle(color: DiggColors.fgSoft, fontSize: 10),
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
