import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme.dart';

/// Horizontally-scrolling row of author avatars + handles + ranks. Used
/// on the home screen as the "Top authors" preview.
class AuthorStrip extends StatelessWidget {
  final List<AuthorCard> authors;
  final void Function(AuthorCard) onTap;
  final double height;

  const AuthorStrip({
    super.key,
    required this.authors,
    required this.onTap,
    this.height = 132,
  });

  @override
  Widget build(BuildContext context) {
    if (authors.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: authors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _Tile(author: authors[i], onTap: () => onTap(authors[i])),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final AuthorCard author;
  final VoidCallback onTap;
  const _Tile({required this.author, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rank = author.rank;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 116,
        padding: const EdgeInsets.all(10),
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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: DiggColors.bgRaised,
                  backgroundImage:
                      author.avatarUrl != null ? NetworkImage(author.avatarUrl!) : null,
                ),
                const Spacer(),
                if (rank != null)
                  Text(
                    '#$rank',
                    style: const TextStyle(
                      color: DiggColors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              author.displayName ?? author.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DiggColors.fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              '@${author.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: DiggColors.fgSoft, fontSize: 11),
            ),
            const Spacer(),
            if (author.category != null)
              Text(
                author.category!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DiggColors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  letterSpacing: 0.4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
