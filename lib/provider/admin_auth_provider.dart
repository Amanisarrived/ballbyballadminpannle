import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ only this

class AdminAuthProvider extends ChangeNotifier {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? currentUser;
  bool isAdmin = false;
  bool isLoading = false;
  String? errorMessage;

  Future<void> checkExistingSession() async {
    isLoading = true;
    notifyListeners();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance
            .collection('admin_auth')
            .doc(currentUser.uid)
            .get();

        if (doc.exists) {
          final role = doc.data()?['role'] as String? ?? '';
          isAdmin = role == 'admin';
        } else {
          isAdmin = false;
        }
      } else {
        isAdmin = false;
      }
    } catch (e) {
      isAdmin = false;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      // 1️⃣ Firebase Auth login
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      currentUser = credential.user;

      // 2️⃣ Firestore admin check
      final adminDoc =
          await _firestore.collection('admin_auth').doc(currentUser!.uid).get();

      if (adminDoc.exists) {
        isAdmin = true;
      } else {
        await _auth.signOut();
        isAdmin = false;
        errorMessage = "You are not authorized as admin.";
      }
    } catch (e) {
      isAdmin = false;
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ================= Logout =================
  Future<void> logout() async {
    await _auth.signOut();
    currentUser = null;
    isAdmin = false;
    notifyListeners();
  }

  // ================= Auto-check on app start =================
  Future<void> checkAdminStatus() async {
    isLoading = true;
    notifyListeners();

    currentUser = _auth.currentUser;

    if (currentUser != null) {
      final adminDoc =
          await _firestore.collection('admin_auth').doc(currentUser!.uid).get();
      isAdmin = adminDoc.exists;
      if (!isAdmin) await _auth.signOut();
    }

    isLoading = false;
    notifyListeners();
  }

  // ================= Utility =================
  bool get isWebPlatform => kIsWeb;
}
