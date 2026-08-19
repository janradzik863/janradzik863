import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Ogłoszenia i alerty priorytetowe (#17) z wykorzystaniem natywnych kanałów
/// powiadomień Androida (NotificationChannel o różnych poziomach ważności).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const channelHigh = 'cwp_high';
  static const channelNormal = 'cwp_normal';

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // Kanały natywne: wysoki priorytet (alert) i normalny (ogłoszenie).
    const high = AndroidNotificationChannel(
      channelHigh,
      'Alerty priorytetowe',
      description: 'Alerty o wysokiej ważności (wymaganie #17).',
      importance: Importance.max,
    );
    const normal = AndroidNotificationChannel(
      channelNormal,
      'Ogłoszenia',
      description: 'Ogłoszenia społecznościowe.',
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(high);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(normal);
  }

  /// Publikuje alert priorytetowy.
  Future<void> showAlert({required String title, required String body}) async {
    await _plugin.show(
      body.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelHigh,
          'Alerty priorytetowe',
          channelDescription: 'Alerty o wysokiej ważności.',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Publikuje zwykłe ogłoszenie.
  Future<void> showAnnouncement(
      {required String title, required String body}) async {
    await _plugin.show(
      title.hashCode ^ DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelNormal,
          'Ogłoszenia',
          channelDescription: 'Ogłoszenia społecznościowe.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }
}
