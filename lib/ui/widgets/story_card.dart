import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../theme.dart';

class StoryCard extends StatelessWidget {
  final Story story;
  final int index;
  final VoidCallback onTap;
  const StoryCard({super.key, required this.story, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = [
      '#${story.rank ?? index + 1}',
      if (story.postCount != null) '${story.postCount} posts',
      if (story.createdAt != null) _timeAgo(story.createdAt!),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: DiggColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta,
              style: const TextStyle(
                color: DiggColors.green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              story.displayTitle,
              style: const TextStyle(
                color: DiggColors.fg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (story.displayTldr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                story.displayTldr,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DiggColors.fgSoft,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            if (story.authors.isNotEmpty) ...[
              const SizedBox(height: 10),
              _AuthorStack(authors: story.authors.take(5).toList()),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthorStack extends StatelessWidget {
  final List<StoryAuthor> authors;
  const _AuthorStack({required this.authors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        children: [
          for (var i = 0; i < authors.length; i++)
            Positioned(
              left: i * 16.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: DiggColors.bg, width: 2),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: authors[i].avatarUrl != null
                        ? Image.network(
                            authors[i].avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: DiggColors.bgSoft),
                          )
                        : Container(color: DiggColors.bgSoft),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _timeAgo(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final diff = DateTime.now().toUtc().difference(t.toUtc());
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(t.toLocal());
}
