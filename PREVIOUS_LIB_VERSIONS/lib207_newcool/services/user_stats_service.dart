// lib/services/user_stats_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucid_dream_trainer/models/mindfulness_score.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import '../models/dream.dart';
import '../models/training_session.dart';
import '../models/sleep_session.dart'; // NEW: Import SleepSession model

class UserStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> saveTrainingSession(TrainingSession session) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('training_sessions')
          .doc(session.id)
          .set(session.toJson());
    } catch (e) {
      debugPrint('Error saving training session: $e');
    }
  }

  Stream<List<SleepSession>> streamSleepSessions() {
    if (currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('sleep_sessions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SleepSession.fromJson(doc.data()))
            .toList());
  }


  // NEW: Save a sleep session after the sleep block is completed.
  Future<void> saveSleepSession(SleepSession session) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('sleep_sessions')
          .doc(session.id)
          .set(session.toJson());
    } catch (e) {
      debugPrint('Error saving sleep session: $e');
    }
  }

  Stream<List<TrainingSession>> streamTrainingSessions() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('training_sessions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrainingSession.fromJson(doc.data()))
            .toList());
  }

  Stream<List<DreamEntry>> streamDreams() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('dreams')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DreamEntry.fromJson(doc.data()))
            .toList());
  }

  Stream<Map<String, dynamic>> streamUserStats() {
      if (currentUserId == null) {
        return Stream.value({
          'totalDreams': 0,
          'lucidDreams': 0,
          'totalTrainingSessions': 0,
          'completedTrainingSessions': 0,
          'sleepSessions': 0,
          'dreams': <DreamEntry>[],
          'trainingSessions': <TrainingSession>[],
        });
      }

      return Rx.combineLatest3(
        streamDreams(),
        streamTrainingSessions(),
        streamSleepSessions(),
        (List<DreamEntry> dreams, List<TrainingSession> trainingSessions, List<SleepSession> sleepSessions) {
          final totalDreams = dreams.length;
          final lucidDreams = dreams.where((dream) => dream.dreams.any((d) => d.isLucid)).length;
          final totalTrainingSessions = trainingSessions.length;
          final completedTrainingSessions = trainingSessions.where((session) => session.completed).length;
          
          return {
            'totalDreams': totalDreams,
            'lucidDreams': lucidDreams,
            'totalTrainingSessions': totalTrainingSessions,
            'completedTrainingSessions': completedTrainingSessions,
            'sleepSessions': sleepSessions,  // Now passing the actual list instead of just the count
            'dreams': dreams,
            'trainingSessions': trainingSessions,
          };
        },
      );
    }

  
  Future<void> updateProfilePicture(int number) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .set({
        'profilePic': number,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating profile picture: $e');
    }
  }

  Future<void> saveMindfulnessScore(MindfulnessScore score) async {
    final uid = _auth.currentUser?.uid;  // Use _auth.currentUser?.uid
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('mindfulness_scores')
          .doc(const Uuid().v4())
          .set(score.toJson());
    } catch (e) {
      debugPrint('Error saving mindfulness score: $e');
    }
  }


  Stream<int> streamProfilePicture() {
    if (currentUserId == null) return Stream.value(1);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['profilePic'] as int? ?? 1);
  }

  Stream<List<MindfulnessScore>> streamMindfulnessScores() {
    if (currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('mindfulness_scores')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MindfulnessScore.fromJson(doc.data()))
            .toList());
  }

}
