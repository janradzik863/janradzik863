import 'package:flutter/foundation.dart';

enum Priority { low, normal, high, critical }

/// Ogłoszenie społecznościowe (#17).
class Announcement {
  final String id;
  final String title;
  final String body;
  final Priority priority;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.createdAt,
  });
}

/// Moduł ogłoszeń i alertów priorytetowych (#17).
///
/// Publikacja alertu o priorytecie high/critical wywołuje natywny kanał
/// powiadomień przez `NotificationService`.
class AnnouncementsService extends ChangeNotifier {
  final NotificationService notifications;
  final List<Announcement> _items = [];

  AnnouncementsService(this.notifications) {
    _seed();
  }

  List<Announcement> get items => List.unmodifiable(_items);

  void _seed() {
    final now = DateTime.now();
    _items.add(Announcement(
      id: 'a1',
      title: 'Wszyscy Won!',
      body: 'Witamy w Czarne Wilki Prawdy.',
      priority: Priority.normal,
      createdAt: now.subtract(const Duration(days: 1)),
    ));
  }

  /// Publikuje nowe ogłoszenie; alerty priorytetowe trafiają na kanał natywny.
  Future<void> publish({
    required String title,
    required String body,
    required Priority priority,
  }) async {
    final a = Announcement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      priority: priority,
      createdAt: DateTime.now(),
    );
    _items.insert(0, a);
    notifyListeners();

    if (priority == Priority.high || priority == Priority.critical) {
      await notifications.showAlert(title: title, body: body);
    } else {
      await notifications.showAnnouncement(title: title, body: body);
    }
  }
}
