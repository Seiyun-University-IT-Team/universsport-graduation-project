import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Requires flutterfire configure to be run by the user)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize Notification Service
    final notificationService = NotificationService();
    await notificationService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: \$e');
  }

  runApp(UniSportApp());
}
