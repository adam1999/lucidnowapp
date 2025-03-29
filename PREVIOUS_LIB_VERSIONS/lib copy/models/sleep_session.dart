// lib/models/sleep_session.dart
class SleepSession {
  final String id;
  final DateTime date;
  final int duration; // in seconds

  SleepSession({
    required this.id,
    required this.date,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'duration': duration,
    };
  }

  factory SleepSession.fromJson(Map<String, dynamic> json) {
    return SleepSession(
      id: json['id'],
      date: DateTime.parse(json['date']),
      duration: json['duration'],
    );
  }
}
