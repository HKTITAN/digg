import 'package:flutter/material.dart';

import '../layout.dart';
import '../../theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? aside;
  final VoidCallback? onMore;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.aside,
    this.onMore,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 10),
  });

  @override
  Widget build(BuildContext context) {
    final compact = isCompactWidth(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.baseline,
        textBaseline: compact ? null : TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: DiggColors.fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                if (aside != null) ...[
                  SizedBox(height: compact ? 2 : 0),
                  Text(
                    aside!.toUpperCase(),
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
            ),
          ),
          if (onMore != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onMore,
              borderRadius: BorderRadius.circular(9999),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Text('See all',
                        style: TextStyle(
                          color: DiggColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 16, color: DiggColors.green),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
