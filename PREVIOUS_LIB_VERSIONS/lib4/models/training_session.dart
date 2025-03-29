// lib/models/training_session.dart

class TrainingSession {
  final String id;
  final DateTime date;
  final int duration; // in seconds
  final bool completed;

  TrainingSession({
    required this.id,
    required this.date,
    required this.duration,
    required this.completed,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'duration': duration,
      'completed': completed,
    };
  }

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'],
      date: DateTime.parse(json['date']),
      duration: json['duration'],
      completed: json['completed'],
    );
  }
}