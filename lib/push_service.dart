import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Runs on its own isolate when a push arrives while the app is backgrounded
/// or killed — must stay top-level (not a method) per firebase_messaging's
/// requirements. Nothing to do here: FCM already shows the system
/// notification for us; this only exists so the plugin can wake the app for
/// [AppState.handlePushTap] if the user taps it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Thin wrapper around FCM: requests notification permission, exposes the
/// current device token, and reports token refreshes. Deliberately doesn't
/// know about the backend or AppState — [onToken] is how the caller learns
/// a token needs (re-)registering.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  void Function(String token)? onToken;

  String get platform => Platform.isIOS ? 'ios' : 'android';

  Future<void> init() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    _messaging.onTokenRefresh.listen((token) => onToken?.call(token));
    final token = await _messaging.getToken();
    if (token != null) onToken?.call(token);
  }
}
