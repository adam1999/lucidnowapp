import 'package:cloud_firestore/cloud_firestore.dart';

class MindfulnessScore {
  final DateTime date;
  final int score;
  MindfulnessScore({required this.date, required this.score});
  
  factory MindfulnessScore.fromJson(Map<String, dynamic> json) {
    return MindfulnessScore(
      date: (json['date'] as Timestamp).toDate(),
      score: json['score'] as int,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'score': score,
    };
  }
}
