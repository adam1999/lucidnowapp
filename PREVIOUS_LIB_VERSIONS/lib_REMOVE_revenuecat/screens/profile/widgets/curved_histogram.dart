// lib/screens/profile/widgets/curved_histogram.dart
import 'package:flutter/material.dart';

class StatItem {
  final String label;
  final int value;
  final Color color;
  const StatItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

class CurvedHistogram extends StatelessWidget {
  final List<StatItem> data;
  const CurvedHistogram({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.8,
      child: CustomPaint(
        painter: _CurvedHistogramPainter(data),
      ),
    );
  }
}

class _CurvedHistogramPainter extends CustomPainter {
  final List<StatItem> data;
  _CurvedHistogramPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 16;
    const double rightPadding = 16;
    const double topPadding = 16;
    const double bottomPadding = 16;
    const double labelHeight = 20;
    final double graphHeight = size.height - topPadding - bottomPadding - labelHeight;
    final double graphBottom = topPadding + graphHeight;
    int maxValue = data.map((d) => d.value).fold(0, (prev, element) => element > prev ? element : prev);
    if (maxValue == 0) maxValue = 1;
    final int barCount = data.length;
    const double barSpacing = 16;
    final double availableWidth = size.width - leftPadding - rightPadding;
    final double barWidth = (availableWidth - (barCount - 1) * barSpacing) / barCount;
    for (int i = 0; i < barCount; i++) {
      final StatItem item = data[i];
      final double left = leftPadding + i * (barWidth + barSpacing);
      final double barHeight = (item.value / maxValue) * graphHeight;
      final double barTop = graphBottom - barHeight;
      final RRect barRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, barTop, barWidth, barHeight),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      );
      // Draw each bar with a vertical gradient.
      final Gradient gradient = LinearGradient(
        colors: [item.color, Color.lerp(item.color, Colors.white, 0.3)!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      final Paint barPaint = Paint()..shader = gradient.createShader(barRect.outerRect);
      canvas.drawRRect(barRect, barPaint);
      // Draw the value above each bar.
      final TextSpan valueSpan = TextSpan(
        text: item.value.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      final TextPainter valuePainter = TextPainter(
        text: valueSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      valuePainter.layout(minWidth: 0, maxWidth: barWidth);
      final Offset valueOffset = Offset(
        left + (barWidth - valuePainter.width) / 2,
        barTop - valuePainter.height - 4,
      );
      valuePainter.paint(canvas, valueOffset);
      // Draw the label below each bar.
      final TextSpan labelSpan = TextSpan(
        text: item.label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      );
      final TextPainter labelPainter = TextPainter(
        text: labelSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout(minWidth: 0, maxWidth: barWidth + 10);
      final Offset labelOffset = Offset(
        left + (barWidth - labelPainter.width) / 2,
        graphBottom + 4,
      );
      labelPainter.paint(canvas, labelOffset);
    }
    // White curve removed.
  }

  @override
  bool shouldRepaint(covariant _CurvedHistogramPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
