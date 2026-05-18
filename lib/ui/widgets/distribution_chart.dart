import 'package:flutter/material.dart';

import '../../theme.dart';

/// Horizontal bar chart for Digg's vibe and topic distributions.
/// Each row: label (left), filled bar (middle), percentage (right).
/// Bars are sorted descending; zero-valued entries are dropped.
class DistributionChart extends StatelessWidget {
  final Map<String, double> data;
  final Color color;
  final int maxRows;
  final double rowHeight;

  const DistributionChart({
    super.key,
    required this.data,
    this.color = DiggColors.green,
    this.maxRows = 8,
    this.rowHeight = 22,
  });

  @override
  Widget build(BuildContext context) {
    final entries = data.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();

    final visible = entries.take(maxRows).toList();
    // Normalize bar widths against the largest value in the visible set so
    // the chart fills its container even when the top value isn't 100%.
    final headroom = visible.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in visible) _Row(
          label: e.key.replaceAll('_', ' '),
          value: e.value,
          fraction: (e.value / headroom).clamp(0.0, 1.0),
          color: color,
          height: rowHeight,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final double value;
  final double fraction;
  final Color color;
  final double height;
  const _Row({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final pctText = value >= 10
        ? '${value.toStringAsFixed(0)}%'
        : '${value.toStringAsFixed(1)}%';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final labelWidth = (constraints.maxWidth * (compact ? 0.3 : 0.36)).clamp(84.0, 120.0);
        final valueWidth = compact ? 40.0 : 44.0;
        return Padding(
          padding: EdgeInsets.only(bottom: height * 0.25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: TextStyle(
                    color: DiggColors.fg,
                    fontSize: compact ? 12 : 13,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fullW = constraints.maxWidth;
                    return Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          height: 6,
                          width: fullW * fraction,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.75)],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              SizedBox(
                width: valueWidth,
                child: Text(
                  pctText,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: DiggColors.fgSoft,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
