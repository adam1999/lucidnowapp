// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:lucid_dream_trainer/models/mindfulness_score.dart';
import 'package:lucid_dream_trainer/models/sleep_session.dart';
import 'package:lucid_dream_trainer/screens/profile/widgets/curved_histogram.dart';
import 'package:lucid_dream_trainer/screens/profile/widgets/mindfulness_chart.dart';
import 'package:lucid_dream_trainer/screens/profile/widgets/time_series_chart.dart';
import 'package:lucid_dream_trainer/screens/profile/widgets/statistic_section.dart';
import 'package:provider/provider.dart';

import '../../models/dream.dart';
import '../../models/training_session.dart';
import '../../translations/app_translations.dart';
import '../../providers/settings_provider.dart';
import 'widgets/dream_calendar.dart';
import 'widgets/profile_pic_selector.dart';
import '../widgets/common_header.dart';
import '../../services/auth_service.dart';
import '../../services/user_stats_service.dart';
import '../auth/login_screen.dart';

class TimeSeriesData {
  final DateTime date;
  final int value;
  TimeSeriesData({required this.date, required this.value});
}

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
          appBar: const CommonHeader(),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0).add(const EdgeInsets.only(bottom: 100)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture Section
                  Center(
                    child: StreamBuilder<int>(
                      stream: statsService.streamProfilePicture(),
                      builder: (context, snapshot) {
                        final profilePicNumber = snapshot.data ?? 1;
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => ProfilePicSelector(
                                currentSelection: profilePicNumber,
                                onSelect: (number) {
                                  statsService.updateProfilePicture(number);
                                },
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFF2D2D36).withOpacity(0.4),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/userpp/$profilePicNumber.png',
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white70,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF1C1C25), width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Profile Section Title and Time Range
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "Profile",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white70,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<TimeRange>(
                        value: _masterTimeRange,
                        dropdownColor: Colors.black,
                        iconEnabledColor: const Color(0xFF5E5DE3),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: TimeRange.overall, child: Text("Overall")),
                          DropdownMenuItem(value: TimeRange.week, child: Text("Week")),
                          DropdownMenuItem(value: TimeRange.month, child: Text("Month")),
                          DropdownMenuItem(value: TimeRange.quarter, child: Text("Quarter")),
                          DropdownMenuItem(value: TimeRange.year, child: Text("Year")),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _masterTimeRange = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Statistics Section
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
                      int periodDays;

                      if (_masterTimeRange == TimeRange.overall) {
                        filteredDreams = allDreams;
                        if (allDreams.isNotEmpty) {
                          DateTime earliest = allDreams.reduce((a, b) => 
                            a.date.isBefore(b.date) ? a : b).date;
                          periodDays = now.difference(earliest).inDays + 1;
                        } else {
                          periodDays = 1;
                        }
                      } else {
                        periodDays = periodDuration.inDays;
                        filteredDreams = allDreams.where((entry) =>
                          !entry.date.isBefore(periodStart) && !entry.date.isAfter(now)
                        ).toList();
                      }

                      return StatisticSection(
                        dreamEntries: filteredDreams,
                        periodDays: periodDays,
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Activity Overview Section
                  Text(
                    "Activity Overview",
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
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: CurvedHistogram(
                          data: [
                            StatItem(
                              label: AppTranslations.translate('totalDreams', settings.currentLanguage),
                              value: totalDreams,
                              color: Colors.green
                            ),
                            StatItem(
                              label: AppTranslations.translate('lucidDreams', settings.currentLanguage),
                              value: lucidDreams,
                              color: Colors.purple
                            ),
                            StatItem(
                              label: AppTranslations.translate('trainingSessions', settings.currentLanguage),
                              value: trainingSessions,
                              color: Colors.blue
                            ),
                            StatItem(
                              label: AppTranslations.translate('Sleep Sessions', settings.currentLanguage),
                              value: sleepSessions,
                              color: Colors.teal
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Dream Vividness Section
                  Text(
                    "Dream Vividness",
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
                            style: const
                            TextStyle(color: Colors.white54),
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
                  const SizedBox(height: 32),


                  // Mindfulness Score Section
                  const SizedBox(height: 32),
                  Text(
                    "Mindfulness Score",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<MindfulnessScore>>(
                    stream: statsService.streamMindfulnessScores(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Text(
                            AppTranslations.translate('noDataAvailable', settings.currentLanguage),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      }
                      // Map the MindfulnessScore data to TimeSeriesData for the chart.
                      List<TimeSeriesData> mindfulnessData = snapshot.data!
                          .map((score) => TimeSeriesData(date: score.date, value: score.score))
                          .toList();
                      return MindfulnessChart(
                        rawData: mindfulnessData,
                        selectedRange: _masterTimeRange,
                      );
                    },
                  ),


                  // Activity Calendar Section
                  Text(
                    AppTranslations.translate('activityCalendar', settings.currentLanguage),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildCalendarLegend(settings),
                  const SizedBox(height: 8),
                  
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
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D36).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: DreamCalendar(
                          dreams: (stats['dreams'] as List<dynamic>).cast<DreamEntry>(),
                          trainingSessions: (stats['trainingSessions'] as List<dynamic>).cast<TrainingSession>(),
                          sleepSessions: (stats['sleepSessions'] as List<dynamic>).cast<SleepSession>(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarLegend(SettingsProvider settings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(AppTranslations.translate('dream', settings.currentLanguage), Colors.green),
        const SizedBox(width: 16),
        _buildLegendItem(AppTranslations.translate('lucidDream', settings.currentLanguage), Colors.purple),
        const SizedBox(width: 16),
        _buildLegendItem(AppTranslations.translate('training', settings.currentLanguage), Colors.blue),
        const SizedBox(width: 16),
        _buildLegendItem(AppTranslations.translate('Sleep Sessions', settings.currentLanguage), Colors.teal),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}