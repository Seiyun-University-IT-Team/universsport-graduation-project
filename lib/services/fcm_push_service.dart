import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FcmPushService {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  
  /// Get OAuth2 access token using the Service Account JSON
  static Future<String?> _getAccessToken() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/service_account.json');
      final Map<String, dynamic> accountCredentials = jsonDecode(jsonString);
      final credentials = ServiceAccountCredentials.fromJson(accountCredentials);

      final client = await clientViaServiceAccount(credentials, _scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      
      return accessToken;
    } catch (e) {
      debugPrint('Error getting FCM access token: $e');
      return null;
    }
  }

  /// Sends a push notification to a specific FCM token
  static Future<void> sendPushMessage({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        debugPrint('Failed to get access token, cannot send push notification.');
        return;
      }

      // Read project ID from the JSON file
      final String jsonString = await rootBundle.loadString('assets/service_account.json');
      final Map<String, dynamic> accountCredentials = jsonDecode(jsonString);
      final projectId = accountCredentials['project_id'];

      final String endpoint = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final message = {
        'message': {
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          if (data != null) 'data': data,
        }
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        debugPrint('Push notification sent successfully!');
      } else {
        debugPrint('Failed to send push notification: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }
}
