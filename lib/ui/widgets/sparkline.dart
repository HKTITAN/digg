import 'package:flutter/material.dart';

/// Tiny inline sparkline. Plots cumulative or raw counts; range is auto-
/// fitted. Fill underneath is the same color at 15% alpha — same look as
/// the browser extension's metric tiles.
class Sparkline extends StatelessWidget {
  final List<num> values;
  final Color color;
  final double height;
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(values, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<num> values;
  final Color color;
  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final arr = values.where((v) => v.isFinite).toList();
    if (arr.length < 2) return;

    final maxV = arr.reduce((a, b) => a > b ? a : b);
    final minV = arr.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs().toDouble().clamp(1.0, double.infinity);
    final step = size.width / (arr.length - 1);

    final line = Path();
    for (var i = 0; i < arr.length; i++) {
      final x = i * step;
      final y = size.height - ((arr[i] - minV) / range) * size.height;
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values || old.color != color;
}
