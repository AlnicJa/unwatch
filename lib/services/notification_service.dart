import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/camera.dart';
import 'location_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _notifId = 0;

  static Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
    );

    _initialized = true;
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showProximityAlert(ProximityAlert alert) async {
    final cam = alert.camera;
    final isClose = alert.severity == AlertSeverity.close;

    final title = isClose
        ? '⚠️ ${cam.typeLabel} Detected'
        : '📍 ${cam.typeLabel} Ahead';

    final body = isClose
        ? '${cam.displayName} — ${alert.distanceLabel}. You are very close.'
        : '${cam.displayName} is ${alert.distanceLabel}';

    final androidDetails = AndroidNotificationDetails(
      'proximity_alerts',
      'Camera Proximity Alerts',
      channelDescription: 'Alerts when approaching surveillance cameras',
      importance: isClose ? Importance.max : Importance.high,
      priority: isClose ? Priority.max : Priority.high,
      enableVibration: true,
      vibrationPattern: isClose
          ? Int64List.fromList([0, 250, 100, 250])
          : Int64List.fromList([0, 200]),

      color: _cameraColor(cam.type),
      icon: '@mipmap/ic_launcher',
      channelShowBadge: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.show(
      _notifId++,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  static Future<void> showNavigationNotif(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'navigation',
      'Navigation',
      channelDescription: 'Navigation instructions',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(presentAlert: false);

    await _plugin.show(
      999,
      'Unwatch Navigation',
      message,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  static Future<void> cancelNavigation() async {
    await _plugin.cancel(999);
  }

  static Color _cameraColor(CameraType type) {
    switch (type) {
      case CameraType.flock:
        return const Color(0xFFFFAA00);
      case CameraType.redLight:
        return const Color(0xFFFF3B3B);
      case CameraType.speed:
        return const Color(0xFF4FA3FF);
      default:
        return const Color(0xFFBF5AF2);
    }
  }
}
