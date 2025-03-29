// lib/screens/profile/widgets/statistic_section.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucid_dream_trainer/models/dream.dart';


enum TimeRange { overall, week, month, quarter, year }

class StatisticSection extends StatelessWidget {
  final List<DreamEntry> dreamEntries;
  final int periodDays;
  const StatisticSection({Key? key, required this.dreamEntries, required this.periodDays}) : super(key: key);

  // Compute the days (yyyy-MM-dd) on which at least one dream was recorded.
  Map<String, bool> get dreamDays {
    Map<String, bool> map = {};
    final now = DateTime.now();
    final periodStart =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: periodDays - 1));
    for (var entry in dreamEntries) {
      if (entry.date.isBefore(periodStart) || entry.date.isAfter(now)) continue;
      String key = DateFormat('yyyy-MM-dd').format(entry.date);
      map[key] = true;
    }
    return map;
  }

  // Compute the days on which at least one lucid dream was recorded.
  Map<String, bool> get lucidDays {
    Map<String, bool> map = {};
    final now = DateTime.now();
    final periodStart =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: periodDays - 1));
    for (var entry in dreamEntries) {
      if (entry.date.isBefore(periodStart) || entry.date.isAfter(now)) continue;
      String key = DateFormat('yyyy-MM-dd').format(entry.date);
      bool hasLucid = entry.dreams.any((dream) => dream.isLucid);
      if (hasLucid) {
        map[key] = true;
      }
    }
    return map;
  }

  double get dreamRate {
    int count = dreamDays.length;
    return (count / periodDays) * 100;
  }

  double get lucidityRate {
    int dreamCount = dreamDays.length;
    if (dreamCount == 0) return 0;
    int lucidCount = lucidDays.length;
    return (lucidCount / dreamCount) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard("Dream Rate", "${dreamRate.toStringAsFixed(0)}%"),
            const SizedBox(width: 16),
            _buildStatCard("Lucidity Rate", "${lucidityRate.toStringAsFixed(0)}%"),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5E5DE3), Color(0xFF7E7DE3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
