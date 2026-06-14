import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isAuthReady = false;
  bool _isRunningAuthOperation = false;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isAuthReady => _isAuthReady;

  AuthProvider() {
    // Listen to Firebase Auth state changes globally
    _auth.authStateChanges().listen((User? user) async {
      if (_isRunningAuthOperation) return;

      if (user != null) {
        final hasProfile = await _fetchAndSetUser(user.uid);
        if (!hasProfile) {
          await _auth.signOut();
        }
      } else {
        _currentUser = null;
        _isAuthReady = true;
        notifyListeners();
      }
    });
  }

  Future<bool> _fetchAndSetUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc);

        // Save FCM token for push notifications
        try {
          await NotificationService().saveUserToken(uid);
          if (_currentUser?.isStudent == true) {
            await NotificationService().subscribeToTopic('all_students');
          } else {
            await NotificationService().unsubscribeFromTopic('all_students');
          }
        } catch (e) {
          debugPrint('Error saving notification token: $e');
        }
      } else {
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      _currentUser = null;
    }
    _isLoading = false;
    _isAuthReady = true;
    notifyListeners();
    return _currentUser != null;
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _isRunningAuthOperation = true;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check user role in Firestore to determine if email verification is needed
      final userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();
        throw StateError('لا توجد بيانات مستخدم مرتبطة بهذا الحساب.');
      }

      final userRole = userDoc.data()?['role'] as String?;
      final isAdminOrSupervisor =
          userRole == 'admin' || userRole == 'supervisor';

      // Only require email verification for students (self-registered accounts)
      if (!credential.user!.emailVerified && !isAdminOrSupervisor) {
        _auth.setLanguageCode("ar");
        await credential.user!.sendEmailVerification();
        await _auth.signOut();
        throw StateError(
          'الرجاء تأكيد البريد الإلكتروني لتسجيل الدخول. لقد أرسلنا رابط تأكيد جديد إلى بريدك.',
        );
      }

      final hasProfile = await _fetchAndSetUser(credential.user!.uid);
      if (!hasProfile) {
        await _auth.signOut();
        throw StateError('لا توجد بيانات مستخدم مرتبطة بهذا الحساب.');
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      _currentUser = null;
      _isLoading = false;
      _isAuthReady = true;
      notifyListeners();
      rethrow; // So UI can show error
    } finally {
      _isRunningAuthOperation = false;
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
    _isRunningAuthOperation = true;
    notifyListeners();

    User? createdUser;

    try {
      // 1. Create Auth User
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = credential.user!.uid;
      createdUser = credential.user;

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

      // Send Email Verification
      if (createdUser != null) {
        _auth.setLanguageCode("ar");
        await createdUser.sendEmailVerification();
      }

      // Sign out immediately so they must verify
      await _auth.signOut();
      _currentUser = null;
      _isLoading = false;
      _isAuthReady = true;
      notifyListeners();

      try {
        await NotificationService().saveUserToken(uid);
        await NotificationService().subscribeToTopic('all_students');
      } catch (e) {
        debugPrint('Error saving notification token: $e');
      }
    } catch (e) {
      debugPrint('Registration Error: $e');
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (deleteError) {
          debugPrint('Error deleting incomplete auth user: $deleteError');
        }
      }
      _currentUser = null;
      _isLoading = false;
      _isAuthReady = true;
      notifyListeners();
      rethrow;
    } finally {
      _isRunningAuthOperation = false;
    }
  }

  Future<void> createAdminAccount({
    required String email,
    required String name,
    required String password,
    UserRole role = UserRole.admin,
    String? college,
  }) async {
    if (_currentUser?.isAdmin != true) {
      throw StateError('Only admins can create admin accounts.');
    }

    _isLoading = true;
    notifyListeners();

    FirebaseApp? secondaryApp;
    User? createdUser;

    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'admin_creation_${DateTime.now().microsecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      createdUser = credential.user;
      final newAdmin = UserModel(
        id: uid,
        name: name,
        email: email,
        role: role,
        college: college,
      );

      await _firestore.collection('users').doc(uid).set(newAdmin.toMap());
      await secondaryAuth.signOut();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (deleteError) {
          debugPrint('Error deleting incomplete admin auth user: $deleteError');
        }
      }
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      await secondaryApp?.delete();
    }
  }

  Future<void> logout() async {
    final wasStudent = _currentUser?.isStudent == true;
    if (wasStudent) {
      try {
        await NotificationService().unsubscribeFromTopic('all_students');
      } catch (e) {
        debugPrint('Error unsubscribing notification topic: $e');
      }
    }
    await _auth.signOut();
    _currentUser = null;
    _isLoading = false;
    _isAuthReady = true;
    notifyListeners();
  }
}
