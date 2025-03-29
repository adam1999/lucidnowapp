import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/dream.dart';

enum TimeRange {
  week,
  month,
  quarter,
  year,
  overall,
}

class TimeSeriesData {
  final DateTime date;
  final int value;
  TimeSeriesData({required this.date, required this.value});
}

class TimeSeriesChart extends StatelessWidget {
  final List<TimeSeriesData> rawData;
  final TimeRange selectedRange;

  const TimeSeriesChart({
    Key? key,
    required this.rawData,
    required this.selectedRange,
  }) : super(key: key);

  String formatDate(DateTime date) {
    switch (selectedRange) {
      case TimeRange.week:
        return DateFormat('E').format(date); // Day of week (Mon, Tue, etc)
      case TimeRange.month:
        return DateFormat('MMM d').format(date); // Feb 15
      case TimeRange.quarter:
      case TimeRange.year:
      case TimeRange.overall:
        return DateFormat('MMM').format(date); // Feb, Mar, etc
    }
  }

  @override
  Widget build(BuildContext context) {
    if (rawData.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D36).withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // Sort and filter data based on time range
    final sortedData = List<TimeSeriesData>.from(rawData)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Find the max value for scaling
    final maxValue = sortedData.fold(0, (max, data) => data.value > max ? data.value : max);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D36).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dream Vividness Trend',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (maxValue > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Max: $maxValue',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ChartPainter(
                data: sortedData,
                maxValue: maxValue > 0 ? maxValue : 5,
                timeRange: selectedRange,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _buildDateLabels(sortedData),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDateLabels(List<TimeSeriesData> data) {
    if (data.isEmpty) return [];
    
    // For week, show first and last day
    if (selectedRange == TimeRange.week || data.length <= 2) {
      return [
        if (data.isNotEmpty)
          Text(
            formatDate(data.first.date),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
            ),
          ),
        if (data.length > 1)
          Text(
            formatDate(data.last.date),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
            ),
          ),
      ];
    }
    
    // For longer ranges, show multiple labels
    final labels = <Widget>[];
    final step = (data.length / 4).ceil();
    
    for (int i = 0; i < data.length; i += step) {
      if (i < data.length) {
        labels.add(
          Text(
            formatDate(data[i].date),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
            ),
          ),
        );
      }
    }
    
    // Make sure we always add the last date
    if (labels.length < 4 && data.isNotEmpty) {
      labels.add(
        Text(
          formatDate(data.last.date),
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
      );
    }
    
    return labels;
  }
}

class _ChartPainter extends CustomPainter {
  final List<TimeSeriesData> data;
  final int maxValue;
  final TimeRange timeRange;

  _ChartPainter({
    required this.data,
    required this.maxValue,
    this.timeRange = TimeRange.week,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Set up paints
    final linePaint = Paint()
      ..color = Colors.purple.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.purple.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (size.height * i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Calculate the date range
    final firstDate = data.first.date;
    final lastDate = data.last.date;
    final dateDiff = lastDate.difference(firstDate).inDays;
    
    // Create paths
    final linePath = Path();
    final fillPath = Path();
    bool pathStarted = false;

    // Add padding to smooth out the edges
    final horizontalPadding = size.width * 0.02;

    // Start the fill path at the bottom left
    fillPath.moveTo(horizontalPadding, size.height);

    List<Offset> points = [];
    
    // Calculate points for smooth curve
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      
      // Calculate x position based on date
      double daysPassed = item.date.difference(firstDate).inDays.toDouble();
      double x = horizontalPadding + ((size.width - (horizontalPadding * 2)) * daysPassed / dateDiff.toDouble());
      
      // Calculate y position based on value
      final y = size.height - (size.height * item.value / maxValue) - 4;
      
      points.add(Offset(x, y));
      
      // Draw data points (smaller and more subtle)
      canvas.drawCircle(Offset(x, y), 2.5, pointPaint);
    }

    // Draw smooth curve using cubic Bezier curves
    if (points.length > 1) {
      linePath.moveTo(points[0].dx, points[0].dy);
      fillPath.lineTo(points[0].dx, points[0].dy);
      
      for (int i = 0; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];
        
        // Control points for cubic Bezier
        final controlPoint1 = Offset(
          current.dx + (next.dx - current.dx) / 2,
          current.dy
        );
        
        final controlPoint2 = Offset(
          current.dx + (next.dx - current.dx) / 2,
          next.dy
        );
        
        linePath.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          next.dx, next.dy
        );
        
        fillPath.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          next.dx, next.dy
        );
      }
    } else if (points.length == 1) {
      // If only one point, draw a line segment
      linePath.moveTo(points[0].dx - 10, points[0].dy);
      linePath.lineTo(points[0].dx + 10, points[0].dy);
      
      fillPath.lineTo(points[0].dx - 10, points[0].dy);
      fillPath.lineTo(points[0].dx + 10, points[0].dy);
    }
    
    // Complete the fill path back to the bottom
    if (points.isNotEmpty) {
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.lineTo(horizontalPadding, size.height);
      fillPath.close();
    }

    // Draw the fill first, then the line
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 