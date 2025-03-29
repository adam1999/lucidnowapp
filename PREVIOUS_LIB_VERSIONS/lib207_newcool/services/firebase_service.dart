import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get currentUserId => _auth.currentUser?.uid;
  bool get isUserSignedIn => _auth.currentUser != null;

  // Authentication methods
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      await _createUserDocument(userCredential.user!.uid);
      
      return userCredential;
    } catch (e) {
      print('Error signing up: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Firestore methods
  Future<void> _createUserDocument(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user document: $e');
      rethrow;
    }
  }

  // Dreams management
  Future<void> saveDream({
    required String title,
    required String content,
    required DateTime date,
    required bool isLucid,
  }) async {
    try {
      if (!isUserSignedIn) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('dreams')
          .add({
        'title': title,
        'content': content,
        'date': Timestamp.fromDate(date),
        'isLucid': isLucid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving dream: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getDreamsStream() {
    if (!isUserSignedIn) return Stream.empty();

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('dreams')
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Training settings management
  Future<void> saveTrainingSettings({
    required Map<String, dynamic> settings,
  }) async {
    try {
      if (!isUserSignedIn) return;

      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('training')
          .set(settings, SetOptions(merge: true));
    } catch (e) {
      print('Error saving settings: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getTrainingSettings() async {
    try {
      if (!isUserSignedIn) return null;

      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('settings')
          .doc('training')
          .get();

      return doc.data();
    } catch (e) {
      print('Error getting settings: $e');
      return null;
    }
  }
}