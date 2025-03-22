// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:lucid_dream_trainer/models/mindfulness_score.dart';
import 'package:lucid_dream_trainer/models/sleep_session.dart';
import 'package:lucid_dream_trainer/screens/profile/widgets/curved_histogram.dart';
import 'package:lucid_dream_trainer/screens/profile/widgets/time_series_chart.dart';
import 'package:lucid_dream_trainer/services/preferences_service.dart';
import 'package:provider/provider.dart';

import '../../models/dream.dart';
import '../../models/training_session.dart';
import '../../translations/app_translations.dart';
import '../../providers/settings_provider.dart';
import '../widgets/common_header.dart';
import '../../services/auth_service.dart';
import '../../services/user_stats_service.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  TimeRange _masterTimeRange = TimeRange.week;

  // Computes the highest vividness per day
  List<TimeSeriesData> computeDailyVividness(List<DreamEntry> dreamEntries) {
    Map<String, int> vividnessMap = {};
    for (var entry in dreamEntries) {
      String key = DateFormat('yyyy-MM-dd').format(entry.date);
      int entryMax = entry.dreams.fold(0, (prev, dream) => 
        dream.vividness > prev ? dream.vividness : prev);
      if (vividnessMap.containsKey(key)) {
        vividnessMap[key] = entryMax > vividnessMap[key]! ? entryMax : vividnessMap[key]!;
      } else {
        vividnessMap[key] = entryMax;
      }
    }
    
    List<TimeSeriesData> dailyData = [];
    vividnessMap.forEach((key, value) {
      dailyData.add(TimeSeriesData(date: DateTime.parse(key), value: value));
    });
    dailyData.sort((a, b) => a.date.compareTo(b.date));
    return dailyData;
  }

  @override
  Widget build(BuildContext context) {
    final statsService = UserStatsService();
    final now = DateTime.now();
    
    // Calculate time period based on selected range
    Duration periodDuration;
    switch (_masterTimeRange) {
      case TimeRange.overall:
        periodDuration = const Duration(days: 0);
        break;
      case TimeRange.week:
        periodDuration = const Duration(days: 7);
        break;
      case TimeRange.month:
        periodDuration = const Duration(days: 30);
        break;
      case TimeRange.quarter:
        periodDuration = const Duration(days: 90);
        break;
      case TimeRange.year:
        periodDuration = const Duration(days: 365);
        break;
    }
    
    DateTime periodStart;
    if (_masterTimeRange == TimeRange.overall) {
      periodStart = DateTime(1900);
    } else {
      periodStart = DateTime(now.year, now.month, now.day)
          .subtract(periodDuration - const Duration(days: 1));
    }

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF06070F),
              Color(0xFF100B1A),
              Color(0xFF1C1326),
              Color(0xFF2F1D34),
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0).add(const EdgeInsets.only(bottom: 100)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section Title and Time Range
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.translate('profile', settings.currentLanguage),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white70,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTimeRangeButtons(),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Activity Overview Section
                  Text(
                    AppTranslations.translate('activityOverview', settings.currentLanguage),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<Map<String, dynamic>>(
                    stream: statsService.streamUserStats(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (!snapshot.hasData) {
                        return Center(
                          child: Text(
                            AppTranslations.translate('noDataAvailable', settings.currentLanguage),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      final stats = snapshot.data!;
                      List<DreamEntry> allDreams = (stats['dreams'] as List<dynamic>).cast<DreamEntry>();
                      List<TrainingSession> allSessions = (stats['trainingSessions'] as List<dynamic>).cast<TrainingSession>();
                      List<SleepSession> allSleepSessions = (stats['sleepSessions'] as List<dynamic>).cast<SleepSession>();

                      List<DreamEntry> filteredDreams;
                      List<TrainingSession> filteredSessions;
                      List<SleepSession> filteredSleepSessions;

                      if (_masterTimeRange == TimeRange.overall) {
                        filteredDreams = allDreams;
                        filteredSessions = allSessions;
                        filteredSleepSessions = allSleepSessions;
                      } else {
                        filteredDreams = allDreams.where((entry) =>
                          !entry.date.isBefore(periodStart) && !entry.date.isAfter(now)
                        ).toList();
                        
                        filteredSessions = allSessions.where((session) =>
                          !session.date.isBefore(periodStart) && !session.date.isAfter(now)
                        ).toList();
                        
                        filteredSleepSessions = allSleepSessions.where((session) =>
                          !session.date.isBefore(periodStart) && !session.date.isAfter(now)
                        ).toList();
                      }

                      int totalDreams = filteredDreams.length;
                      int lucidDreams = filteredDreams.where((entry) =>
                        entry.dreams.any((dream) => dream.isLucid)
                      ).length;
                      int trainingSessions = filteredSessions.length;
                      int sleepSessions = filteredSleepSessions.length;

                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D36).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // First row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    label: AppTranslations.translate('totalDreams', settings.currentLanguage),
                                    value: totalDreams.toString(),
                                    icon: Icons.cloud_outlined,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    label: AppTranslations.translate('lucidDreams', settings.currentLanguage),
                                    value: lucidDreams.toString(),
                                    icon: Icons.psychology_outlined,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Second row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    label: AppTranslations.translate('trainingSessions', settings.currentLanguage),
                                    value: trainingSessions.toString(),
                                    icon: Icons.self_improvement_outlined,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    label: AppTranslations.translate('sleepSessions', settings.currentLanguage),
                                    value: sleepSessions.toString(),
                                    icon: Icons.bedtime_outlined,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Dream Vividness Section
                  Text(
                    AppTranslations.translate('dreamVividness', settings.currentLanguage),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  StreamBuilder<Map<String, dynamic>>(
                    stream: statsService.streamUserStats(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (!snapshot.hasData) {
                        return Center(
                          child: Text(
                            AppTranslations.translate('noDataAvailable', settings.currentLanguage),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      }

                      final stats = snapshot.data!;
                      List<DreamEntry> allDreams = (stats['dreams'] as List<dynamic>).cast<DreamEntry>();
                      List<DreamEntry> filteredDreams;
                      
                      if (_masterTimeRange == TimeRange.overall) {
                        filteredDreams = allDreams;
                      } else {
                        filteredDreams = allDreams.where((entry) =>
                          !entry.date.isBefore(periodStart) && !entry.date.isAfter(now)
                        ).toList();
                      }
                      
                      List<TimeSeriesData> dailyVividness = computeDailyVividness(filteredDreams);
                      return TimeSeriesChart(
                        rawData: dailyVividness,
                        selectedRange: _masterTimeRange,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeButtons() {
    final settings = Provider.of<SettingsProvider>(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Row(
        children: [
          _buildTimeRangeButton(TimeRange.week, AppTranslations.translate('week', settings.currentLanguage)),
          const SizedBox(width: 6),
          _buildTimeRangeButton(TimeRange.month, AppTranslations.translate('month', settings.currentLanguage)),
          const SizedBox(width: 6),
          _buildTimeRangeButton(TimeRange.quarter, AppTranslations.translate('quarter', settings.currentLanguage)),
          const SizedBox(width: 6),
          _buildTimeRangeButton(TimeRange.year, AppTranslations.translate('year', settings.currentLanguage)),
          const SizedBox(width: 6),
          _buildTimeRangeButton(TimeRange.overall, AppTranslations.translate('allTime', settings.currentLanguage)),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(TimeRange range, String label) {
    final isSelected = _masterTimeRange == range;
    
    return ElevatedButton(
      onPressed: () {
        setState(() => _masterTimeRange = range);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF5E5DE3) : const Color(0xFF2D2D36).withOpacity(0.4),
        foregroundColor: Colors.white,
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(10, 32),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // Add this helper method for creating stat cards
  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}