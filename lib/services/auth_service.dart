import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 1. Add this import
import 'package:flutter/material.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db =
      FirebaseFirestore.instance; // 2. Initialize Firestore

  Stream<User?> get user => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      User? user = result.user;

      if (user != null) {
        await user.updateDisplayName(name);

        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'customCategories': [], // Useful for your expense logic later
        });
      }

      notifyListeners();
    } on FirebaseAuthException catch (e) {
      debugPrint("Registration Error: ${e.message}");
      rethrow;
    }
  }

  // SIGN IN
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      debugPrint("Login Error: ${e.message}");
      rethrow;
    }
  }

  // SIGN OUT
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
