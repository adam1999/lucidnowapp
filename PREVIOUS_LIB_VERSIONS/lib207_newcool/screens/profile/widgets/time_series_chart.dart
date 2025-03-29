// lib/screens/profile/widgets/time_series_chart.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../profile_screen.dart';
import 'statistic_section.dart' show TimeRange;

class TimeSeriesChart extends StatelessWidget {
  final List<TimeSeriesData> rawData;
  final TimeRange selectedRange;
  const TimeSeriesChart({Key? key, required this.rawData, required this.selectedRange}) : super(key: key);

  List<TimeSeriesData> _aggregateWeeklyData(List<TimeSeriesData> dailyData) {
    Map<DateTime, List<int>> grouped = {};
    for (var data in dailyData) {
      DateTime monday = data.date.subtract(Duration(days: data.date.weekday - 1));
      monday = DateTime.utc(monday.year, monday.month, monday.day);
      grouped[monday] = (grouped[monday] ?? [])..add(data.value);
    }
    List<TimeSeriesData> aggregated = [];
    grouped.forEach((monday, values) {
      double avg = values.reduce((a, b) => a + b) / values.length;
      aggregated.add(TimeSeriesData(date: monday, value: avg.round()));
    });
    aggregated.sort((a, b) => a.date.compareTo(b.date));
    return aggregated;
  }

  List<TimeSeriesData> _aggregateMonthlyData(List<TimeSeriesData> dailyData) {
    Map<String, List<int>> grouped = {};
    for (var data in dailyData) {
      String key = '${data.date.year}-${data.date.month.toString().padLeft(2, '0')}';
      grouped[key] = (grouped[key] ?? [])..add(data.value);
    }
    List<TimeSeriesData> aggregated = [];
    grouped.forEach((key, values) {
      double avg = values.reduce((a, b) => a + b) / values.length;
      int year = int.parse(key.split('-')[0]);
      int month = int.parse(key.split('-')[1]);
      aggregated.add(TimeSeriesData(date: DateTime.utc(year, month, 1), value: avg.round()));
    });
    aggregated.sort((a, b) => a.date.compareTo(b.date));
    return aggregated;
  }

  List<TimeSeriesData> get filteredData {
    final now = DateTime.now(); // Use local time
    if (selectedRange == TimeRange.overall) {
      return rawData;
    }
    
    late DateTime startDate;
    switch (selectedRange) {
      case TimeRange.week:
        startDate = now.subtract(const Duration(days: 7));
        break;
      case TimeRange.month:
        startDate = now.subtract(const Duration(days: 30));
        break;
      case TimeRange.quarter:
        startDate = now.subtract(const Duration(days: 90));
        break;
      case TimeRange.year:
        startDate = now.subtract(const Duration(days: 365));
        break;
      default:
        startDate = now;
    }

    Map<DateTime, int> dataMap = {};
    for (var entry in rawData) {
      // Create date key in local time, zeroing out time portion
      final key = DateTime(entry.date.year, entry.date.month, entry.date.day);
      dataMap[key] = entry.value;
    }

    List<TimeSeriesData> daily = [];
    // Start from beginning of startDate in local time
    DateTime day = DateTime(startDate.year, startDate.month, startDate.day);
    // Use end of current day as the cutoff
    DateTime endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    while (!day.isAfter(endOfToday)) {
      daily.add(TimeSeriesData(date: day, value: dataMap[day] ?? 0));
      day = day.add(const Duration(days: 1));
    }

    if (selectedRange == TimeRange.quarter) {
      return _aggregateWeeklyData(daily);
    } else if (selectedRange == TimeRange.year) {
      return _aggregateMonthlyData(daily);
    }
    return daily;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D36).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: 1.8,
        child: CustomPaint(
          painter: TimeSeriesChartPainter(filteredData, selectedRange),
        ),
      ),
    );
  }
}

class TimeSeriesChartPainter extends CustomPainter {
  final List<TimeSeriesData> data;
  final TimeRange selectedRange;
  TimeSeriesChartPainter(this.data, this.selectedRange);

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 40;
    const double rightPadding = 16;
    const double topPadding = 16;
    const double bottomPadding = 40;
    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    int maxValue = data.map((d) => d.value).fold(0, (prev, curr) => curr > prev ? curr : prev);
    if (maxValue == 0) maxValue = 5;

    int n = data.length;
    if (n == 0) return;
    List<Offset> points = [];
    for (int i = 0; i < n; i++) {
      final d = data[i];
      double x = leftPadding + (chartWidth) * (n == 1 ? 0.5 : i / (n - 1));
      double y = topPadding + chartHeight - ((d.value / maxValue) * chartHeight);
      points.add(Offset(x, y));
    }

    if (points.length >= 2) {
      final Path curvePath = Path();
      curvePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final double controlX = (prev.dx + curr.dx) / 2;
        curvePath.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
      }
      final Rect shaderRect = Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight);
      final Paint curvePaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF5E5DE3), Color(0xFF7E7DE3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(shaderRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(curvePath, curvePaint);
    }

    int labelInterval = 1;
    if (n > 10) labelInterval = (n / 5).ceil();
    for (int i = 0; i < n; i++) {
      if (i % labelInterval == 0 || i == n - 1) {
        final d = data[i];
        String label = selectedRange == TimeRange.year
            ? DateFormat('MMM').format(d.date)
            : DateFormat('MM/dd').format(d.date);
        final TextSpan span = TextSpan(
          text: label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        );
        final TextPainter tpLabel = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        );
        tpLabel.layout(minWidth: 0, maxWidth: 50);
        double x = leftPadding + (chartWidth) * (n == 1 ? 0.5 : i / (n - 1));
        double y = topPadding + chartHeight + 4;
        tpLabel.paint(canvas, Offset(x - tpLabel.width / 2, y));
      }
    }

    final TextSpan yLabelMin = TextSpan(
      text: '0',
      style: const TextStyle(color: Colors.white70, fontSize: 10),
    );
    final TextPainter tpYMin = TextPainter(
      text: yLabelMin,
      textDirection: ui.TextDirection.ltr,
    );
    tpYMin.layout();
    tpYMin.paint(canvas, Offset(0, topPadding + chartHeight - tpYMin.height / 2));

    final TextSpan yLabelMax = TextSpan(
      text: '$maxValue',
      style: const TextStyle(color: Colors.white70, fontSize: 10),
    );
    final TextPainter tpYMax = TextPainter(
      text: yLabelMax,
      textDirection: ui.TextDirection.ltr,
    );
    tpYMax.layout();
    tpYMax.paint(canvas, Offset(0, topPadding - tpYMax.height / 2));
  }

  @override
  bool shouldRepaint(covariant TimeSeriesChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.selectedRange != selectedRange;
  }
}
