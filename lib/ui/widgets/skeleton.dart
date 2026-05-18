import 'package:flutter/material.dart';

import '../../theme.dart';

/// Animated skeleton placeholder. A subtle shimmer that runs left-to-right
/// across a rounded rectangle. Use to fill the shape of upcoming content
/// instead of spinning a generic loader — the perceived load time is much
/// shorter when the skeleton matches the eventual layout.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 6});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: SizedBox(
            width: widget.width ?? double.infinity,
            height: widget.height,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) {
                // A pale band sweeps from left (-1) to right (+2) over the
                // animation cycle.
                final t = _c.value;
                return LinearGradient(
                  begin: Alignment(t * 3 - 1.5, 0),
                  end: Alignment(t * 3 - 0.5, 0),
                  colors: const [
                    Color(0x14FFFFFF),
                    Color(0x2EFFFFFF),
                    Color(0x14FFFFFF),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(rect);
              },
              child: Container(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton row sized to match a [StoryCard]. Shown while the feed loads.
class StoryCardSkeleton extends StatelessWidget {
  const StoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DiggColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Skeleton(width: 110, height: 10, radius: 4),
          SizedBox(height: 10),
          Skeleton(height: 16, radius: 6),
          SizedBox(height: 8),
          Skeleton(height: 14, width: 280, radius: 5),
          SizedBox(height: 4),
          Skeleton(height: 14, width: 200, radius: 5),
          SizedBox(height: 12),
          SizedBox(
            height: 22,
            child: Row(
              children: [
                Skeleton(width: 22, height: 22, radius: 11),
                SizedBox(width: 4),
                Skeleton(width: 22, height: 22, radius: 11),
                SizedBox(width: 4),
                Skeleton(width: 22, height: 22, radius: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeedSkeleton extends StatelessWidget {
  final int count;
  const FeedSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (_, __) => const StoryCardSkeleton(),
    );
  }
}
