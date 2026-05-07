import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    // Listen to Firebase Auth state changes globally
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _fetchAndSetUser(user.uid);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchAndSetUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!);
        
        // Save FCM token for push notifications
        await NotificationService().saveUserToken(uid);
      } else {
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('Error fetching user data: \$e');
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // _fetchAndSetUser will be called automatically by authStateChanges listener
    } catch (e) {
      debugPrint('Login Error: \$e');
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      rethrow; // So UI can show error
    }
  }

  Future<void> registerStudent({
    required String email,
    required String name,
    required String studentId,
    required String college,
    required String department,
    required String academicLevel,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Create Auth User
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      // 2. Create UserModel
      final newUser = UserModel(
        id: uid,
        name: name,
        email: email,
        role: UserRole.student,
        studentId: studentId,
        college: college,
        department: department,
        academicLevel: academicLevel,
      );

      // 3. Save to Firestore
      await _firestore.collection('users').doc(uid).set(newUser.toMap());
      
      // _fetchAndSetUser will be called automatically by authStateChanges listener
    } catch (e) {
      debugPrint('Registration Error: \$e');
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
