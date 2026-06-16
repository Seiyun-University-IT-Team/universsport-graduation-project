import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/user_repository.dart';

// Must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: \${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || Platform.isWindows) {
      _isInitialized = true;
      return;
    }

    // 1. Request permissions for iOS and Android 13+
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions.');
    } else {
      debugPrint('User declined or has not accepted permissions.');
    }

    // 2. Initialize Local Notifications (For Foreground display)
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(settings: initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'unisport_channel_id',
      'إشعارات رياضة جامعة سيئون',
      description: 'إشعارات المباريات والموافقات',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Set up Background Message Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Set up Foreground Message Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: \${message.data}');

      if (message.notification != null) {
        showLocalNotification(
          title: message.notification?.title ?? 'إشعار جديد', 
          body: message.notification?.body ?? '',
        );
      }
    });

    _isInitialized = true;
  }

  Future<void> showLocalNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'unisport_channel_id',
      'إشعارات رياضة جامعة سيئون',
      channelDescription: 'إشعارات المباريات والموافقات',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  /// Retrieves the FCM token and saves it to the user's document in Firestore.
  /// This token is required so your backend (Cloud Functions) knows which device to ping.
  Future<void> saveUserToken(String userId) async {
    if (kIsWeb || Platform.isWindows) return;
    try {
      String? token;
      
      // APNS Token check for iOS
      if (Platform.isIOS) {
        token = await _fcm.getAPNSToken();
      }
      
      token = await _fcm.getToken();

      if (token != null) {
        final UserRepository userRepo = UserRepository();
        final user = await userRepo.getUserById(userId);
        if (user != null) {
          // You would typically add an fcmToken field to UserModel.
          // For now, we update it dynamically into Firestore.
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'fcm_token': token,
          });
          debugPrint('FCM Token Saved for User: $userId');
        }
      }

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'fcm_token': newToken,
        });
      });

    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Subscribes the device to a specific topic (e.g. 'all_students', 'competition_123')
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb || Platform.isWindows) return;
    await _fcm.subscribeToTopic(topic);
  }

  /// Unsubscribes the device from a specific topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb || Platform.isWindows) return;
    await _fcm.unsubscribeFromTopic(topic);
  }
}

