import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password
      );
      
      // Update last login
      await _firestore.collection('users').doc(credential.user!.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      
      return credential;
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password
      );
      
      // Create user document
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      
      return credential;
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Save dream to Firestore
  Future<void> saveDream(String title, String description, DateTime date, bool isLucid) async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) return;

      await _firestore.collection('users').doc(uid).collection('dreams').add({
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
        'isLucid': isLucid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving dream: $e');
      rethrow;
    }
  }

  // Get dreams stream
  Stream<QuerySnapshot> getDreamsStream() {
    final uid = currentUser?.uid;
    if (uid == null) return Stream.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('dreams')
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Generate nonce for Apple Sign In
  String generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  // SHA256 hash
  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      // Create/update user document
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': userCredential.user!.email,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'provider': 'google',
      }, SetOptions(merge: true));

      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return null;
    }
  }

  // Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      // Trigger the Apple sign-in flow
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);
      
      // Request credential for the currently signed in Apple account
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      // Create an OAuthCredential from the credential returned by Apple
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      
      // Sign in to Firebase with the Apple OAuthCredential
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      
      // Update the username if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        // Try to use the name from Apple ID
        String displayName = userCredential.user?.displayName ?? '';
        
        // If no display name, try to construct from Apple credential
        if (displayName.isEmpty) {
          if (appleCredential.givenName != null && appleCredential.familyName != null) {
            displayName = '${appleCredential.givenName} ${appleCredential.familyName}';
          } else if (appleCredential.givenName != null) {
            displayName = appleCredential.givenName!;
          } else if (appleCredential.familyName != null) {
            displayName = appleCredential.familyName!;
          }
        }
        
        // Update user profile if we have a display name
        if (displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
        }
      }
      
      return userCredential;
    } catch (e) {
      debugPrint('Error with Apple Sign In: $e');
      return null;
    }
  }
}