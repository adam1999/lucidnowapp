// lib/screens/profile/widgets/dream_calendar.dart

import 'package:flutter/material.dart';
import '../../../../lib_200/models/sleep_session.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/dream.dart';
import '../../../models/training_session.dart';

class DreamCalendar extends StatefulWidget {
  final List<DreamEntry> dreams;
  final List<TrainingSession> trainingSessions;
  final List<SleepSession> sleepSessions;

  const DreamCalendar({
    super.key,
    required this.dreams,
    required this.trainingSessions,
    required this.sleepSessions,
  });

  @override
  State<DreamCalendar> createState() => _DreamCalendarState();
}

class _DreamCalendarState extends State<DreamCalendar> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late Map<DateTime, Set<String>> _events;  // Changed to Set for unique event types

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _initializeEvents();
  }

  @override
  void didUpdateWidget(DreamCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeEvents();
  }

  void _initializeEvents() {
    _events = {};

    // Process dreams
    for (var dream in widget.dreams) {
      final date = DateTime(dream.date.year, dream.date.month, dream.date.day);
      _events[date] = _events[date] ?? <String>{};
      
      // If any dream is lucid, mark as lucid, otherwise mark as regular dream
      if (dream.dreams.any((d) => d.isLucid)) {
        _events[date]!.add('lucid_dream');
        // Remove regular dream if exists (lucid takes priority)
        _events[date]!.remove('dream');
      } else if (!_events[date]!.contains('lucid_dream')) {
        // Only add regular dream if no lucid dream exists
        _events[date]!.add('dream');
      }
    }

    // Process training sessions
    for (var session in widget.trainingSessions) {
      final date = DateTime(session.date.year, session.date.month, session.date.day);
      _events[date] = _events[date] ?? <String>{};
      _events[date]!.add('training');
    }

    // Process sleep sessions
    for (var session in widget.sleepSessions) {
      final date = DateTime(session.date.year, session.date.month, session.date.day);
      _events[date] = _events[date] ?? <String>{};
      _events[date]!.add('sleep');
    }
  }

  List<String> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay]?.toList() ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.now(),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: TextStyle(color: Colors.white70),
        defaultTextStyle: TextStyle(color: Colors.white),
        todayDecoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Colors.purple,
          shape: BoxShape.circle,
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      eventLoader: _getEventsForDay,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;

          final List<String> eventsList = events.cast<String>();
          // Sort events to maintain consistent order
          eventsList.sort();
          
          return Positioned(
            bottom: 1,
            left: 1,
            right: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: eventsList.map<Widget>((eventType) {
                Color dotColor;
                
                switch (eventType) {
                  case 'dream':
                    dotColor = Colors.green;
                    break;
                  case 'lucid_dream':
                    dotColor = Colors.purple;
                    break;
                  case 'training':
                    dotColor = Colors.blue;
                    break;
                  case 'sleep':
                    dotColor = Colors.teal;
                    break;
                  default:
                    dotColor = Colors.transparent;
                }
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}