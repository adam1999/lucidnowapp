import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
      print('Error signing in: $e');
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
      print('Error signing up: $e');
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
      print('Error saving dream: $e');
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
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.tardam.lucidnow.signin',
          redirectUri: Uri.parse(
            'https://lucidnow-c2628.firebaseapp.com/__/auth/handler'
          ),
        ),
      );

      print('Apple Sign In Response:');
      print('Identity Token Length: ${appleCredential.identityToken?.length}');
      print('Authorization Code Length: ${appleCredential.authorizationCode.length}');
      print('Raw Nonce: $rawNonce');
      print('Hashed Nonce: $nonce');
      print('User ID: ${appleCredential.userIdentifier}');

      if (appleCredential.identityToken == null) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Apple Sign In response missing identity token',
        );
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken!,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      
      // Save user data
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'firstName': appleCredential.givenName,
          'lastName': appleCredential.familyName,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'provider': 'apple',
        }, SetOptions(merge: true));
      }

      return userCredential;
    } catch (e) {
      print('Detailed Apple Sign In Error: $e');
      rethrow;
    }
  }
}