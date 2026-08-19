import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Punkt 17: Natywne kanały powiadomień — ogłoszenia i alerty priorytetowe.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _initialized = true;
      return; // desktop: powiadomienia lokalne nie są wymagane
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;

    // Tworzenie kanałów (Android 8.0+)
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'cw_alerts',
          'Alerty Czarnych Wilków',
          description: 'Priorytetowe ogłoszenia i alerty',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'cw_general',
          'Ogłoszenia ogólne',
          description: 'Powiadomienia ogólne aplikacji',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Wyświetl powiadomienie na kanale ogłoszeń.
  Future<void> showAnnouncement({
    required int id,
    required String title,
    required String body,
    bool critical = false,
  }) async {
    if (!_initialized) await init();
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        critical ? 'cw_alerts' : 'cw_general',
        critical ? 'Alerty Czarnych Wilków' : 'Ogłoszenia ogólne',
        importance: critical ? Importance.high : Importance.defaultImportance,
        priority: critical ? Priority.high : Priority.defaultPriority,
        color: const Color(0xFFDC143C),
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(id, title, body, details);
  }

  /// Wyświetl powiadomienie o nowej wiadomości w komunikatorze.
  Future<void> showMessageNotification({
    required int id,
    required String sender,
    required String preview,
  }) async {
    if (!_initialized) await init();
    if (!Platform.isAndroid && !Platform.isIOS) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'cw_alerts',
        'Alerty Czarnych Wilków',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(id, 'Wiadomość od $sender', preview, details);
  }
}


