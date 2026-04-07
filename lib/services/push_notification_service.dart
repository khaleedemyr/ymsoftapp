import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize push notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize local notifications for Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          print('Notification tapped: ${response.payload}');
          // TODO: Navigate to specific screen based on notification data
        },
      );

      // Create notification channel for Android (required for Android 8.0+)
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        const androidChannel = AndroidNotificationChannel(
          'fcm_channel',
          'FCM Notifications',
          description: 'Notifications from YM Soft ERP',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        
        await androidImplementation.createNotificationChannel(androidChannel);
        print('Android notification channel created');
      }

      // Request permission for iOS
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('Push notification permission: ${settings.authorizationStatus}');
      print('Push notification settings: alert=${settings.alert}, badge=${settings.badge}, sound=${settings.sound}, provisional=${settings.authorizationStatus == AuthorizationStatus.provisional}');

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received foreground message: ${message.messageId}');
        _showLocalNotification(message);
      });

      // Handle background messages (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Notification opened app: ${message.messageId}');
        // TODO: Navigate to specific screen based on notification data
      });

      // Handle notification when app is opened from terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print('App opened from notification: ${initialMessage.messageId}');
        // TODO: Navigate to specific screen based on notification data
      }

      // Handle token refresh
      _messaging.onTokenRefresh.listen((String token) {
        print('FCM Token refreshed: ${token.substring(0, 20)}...');
        // TODO: Update token to backend
      });

      _initialized = true;
      print('Push notification service initialized');

      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        print('Initial APNs token from FirebaseMessaging: ${apnsToken ?? 'null'}');
      }
    } catch (e) {
      print('Error initializing push notification service: $e');
    }
  }

  /// Show local notification for foreground messages
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'fcm_channel',
        'FCM Notifications',
        channelDescription: 'Notifications from YM Soft ERP',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? '',
        notificationDetails,
        payload: message.data.toString(),
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  /// Get FCM token
  static Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        for (var attempt = 0; attempt < 10; attempt++) {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) {
            print('APNs token available on attempt ${attempt + 1}: $apnsToken');
            break;
          }

          print('APNs token still null on attempt ${attempt + 1}');

          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      final token = await _messaging.getToken();
      print('FCM token fetch result: ${token == null ? 'null' : '${token.substring(0, 20)}...'}');
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }
}

