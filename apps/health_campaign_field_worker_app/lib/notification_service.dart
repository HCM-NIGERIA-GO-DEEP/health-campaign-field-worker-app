import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level background message handler for FCM.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the system notification tray.
  // No additional processing needed here.
  debugPrint('FCM background message: ${message.messageId}');
}

/// SharedPreferences key that holds a re-verification trigger index whose
/// notification tap arrived before the in-app scheduler/bloc was ready
/// (cold-start or main-isolate race). ReVerificationScheduler.start() drains
/// this key and dispatches the trigger so the very first tap of a session
/// never gets dropped.
const String reVerifyPendingTapKey = 'face_reverification_pending_tap';

/// Persist a re-verification trigger index that was tapped but couldn't be
/// dispatched in-app yet (callback not wired, bloc not built). Safe to call
/// from any isolate.
@pragma('vm:entry-point')
Future<void> _persistPendingReVerifyTap(int index) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(reVerifyPendingTapKey, index);
    debugPrint(
        'NotificationService: persisted pending re-verify tap #$index for scheduler drain');
  } catch (e) {
    debugPrint('NotificationService: _persistPendingReVerifyTap failed: $e');
  }
}

/// Top-level handler for local-notification taps when the app is in the
/// background OR terminated. Must be a top-level function annotated with
/// @pragma('vm:entry-point') so it survives tree-shaking and can be invoked
/// by the OS from a fresh isolate. Routes the tap through the singleton so
/// the foreground scheduler picks it up once the main isolate is ready.
@pragma('vm:entry-point')
void onBackgroundNotificationTapped(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  debugPrint('NotificationService: background tap, payload=$payload');
  if (payload.startsWith(NotificationService.reVerifyPayloadPrefix)) {
    final indexStr =
        payload.substring(NotificationService.reVerifyPayloadPrefix.length);
    final index = int.tryParse(indexStr);
    if (index != null) {
      // Persist FIRST so a race where the main isolate hasn't yet set
      // onReVerificationTap still leaves a marker for the scheduler to drain.
      _persistPendingReVerifyTap(index);
      NotificationService().onReVerificationTap?.call(index);
    }
  }
}

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when user taps a notification.
  /// The map contains the FCM data payload.
  void Function(Map<String, dynamic>)? onNotificationTap;
  void Function(int triggerIndex)? onReVerificationTap;

  static const String reVerifyPayloadPrefix = 'reverify:';
  static const String _fcmTokenKey = 'fcm_device_token';
  static const String _fcmTokenMapKey = 'fcm_device_token_map';
  static const String _channelId = 'fcm_default_channel';
  static const String _channelName = 'Push Notifications';
  static const String _channelDescription =
      'Channel for FCM push notifications';

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationTapped,
    );

    // Create the Android notification channel
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Initialize FCM: request permissions, get token, set up listeners.
  Future<String?> initializeFCM() async {
    debugPrint('FCM: Starting initialization...');
    final messaging = FirebaseMessaging.instance;

    // Request notification permissions
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('FCM: Permission status = ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM: User denied notification permissions');
      return null;
    }

    // Get and store the FCM token
    final token = await messaging.getToken();
    debugPrint('FCM: Token received = ${token != null ? 'YES' : 'NULL'}');
    if (token != null) {
      await _storeFcmToken(token);
    } else {
      debugPrint('FCM: WARNING - getToken() returned null');
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      await _storeFcmToken(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle notification tap when app was terminated
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    return token;
  }

  /// Fixed notification IDs so foreground FCM messages REPLACE each other
  /// in the tray instead of stacking. Re-verification FCMs share the same
  /// id as the local scheduler so an FCM-delivered prompt replaces a stale
  /// scheduled one rather than queuing alongside it.
  static const int _fcmFaceVerifyNotifId = 9000;
  static const int _fcmGeneralNotifId = 9001;

  /// Show a local notification banner for foreground FCM messages.
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final isReVerify = message.data['type'] == 'FACE_REVERIFICATION' ||
        (notification.title?.contains('Face Verification') ?? false);
    final notifId = isReVerify ? _fcmFaceVerifyNotifId : _fcmGeneralNotifId;

    flutterLocalNotificationsPlugin.show(
      notifId,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _encodePayload(message.data),
    );
  }

  /// Called when user taps on a local notification.
  /// Routes re-verification taps (payload starting with `reverify:N`) to
  /// onReVerificationTap; everything else is treated as an FCM payload.
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    debugPrint('NotificationService: foreground tap, payload=$payload');

    if (payload.startsWith(reVerifyPayloadPrefix)) {
      final indexStr = payload.substring(reVerifyPayloadPrefix.length);
      final index = int.tryParse(indexStr);
      if (index != null) {
        // Persist first so even if the scheduler/bloc isn't ready yet
        // (cold-start race where the user taps before init completes), the
        // scheduler can drain this on start() and surface the popup.
        _persistPendingReVerifyTap(index);
        onReVerificationTap?.call(index);
      }
      return;
    }

    final data = _decodePayload(payload);
    onNotificationTap?.call(data);
  }

  /// Called when user taps on an FCM notification (background/terminated).
  void _handleMessageOpenedApp(RemoteMessage message) {
    onNotificationTap?.call(message.data);
  }

  /// Store FCM token in SharedPreferences.
  Future<void> _storeFcmToken(String token) async {
    debugPrint('═══════════════════════════════════════════');
    debugPrint('FCM TOKEN (copied to clipboard):');
    debugPrint(token);
    debugPrint('═══════════════════════════════════════════');
    // await Clipboard.setData(ClipboardData(text: token));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);
  }

  /// Retrieve stored FCM token.
  static Future<String?> getStoredFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenKey);
  }

  /// Encode a data map as a simple key=value payload string.
  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// Decode a payload string back to a map.
  Map<String, dynamic> _decodePayload(String payload) {
    final map = <String, dynamic>{};
    for (final part in payload.split('&')) {
      final index = part.indexOf('=');
      if (index > 0) {
        map[part.substring(0, index)] = part.substring(index + 1);
      }
    }
    return map;
  }

  /// Store FCM token in SharedPreferences map against userId.
  static Future<void> storeTokenForUser(String userId, String token) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _getTokenMap();
    map[userId] = token;
    await prefs.setString(_fcmTokenMapKey, jsonEncode(map));
    debugPrint('FCM: Stored token for user $userId');
  }

  /// Retrieve stored FCM token for a specific user.
  static Future<String?> getTokenForUser(String userId) async {
    final map = await _getTokenMap();
    return map[userId];
  }

  /// Get the full token map from SharedPreferences.
  static Future<Map<String, String>> _getTokenMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_fcmTokenMapKey);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }
}
