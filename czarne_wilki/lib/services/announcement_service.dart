import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import 'notification_service.dart';

/// Punkt 17: Ogłoszenia i alerty priorytetowe.
class AnnouncementService extends ChangeNotifier {
  AnnouncementService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;
  List<Announcement> _items = [];

  List<Announcement> get items => _items;
  int get unreadCount => _items.where((a) => !a.read).length;

  Future<void> load() async {
    _items = await _db.listAnnouncements();
    notifyListeners();
  }

  /// Utwórz ogłoszenie i wyślij powiadomienie natywne.
  Future<void> create({
    required String title,
    required String body,
    AnnouncementPriority priority = AnnouncementPriority.normal,
  }) async {
    final a = await _db.addAnnouncement(Announcement(
      id: 0,
      title: title,
      body: body,
      priority: priority,
    ));

    // Powiadomienie natywne (kanały Android)
    await NotificationService.instance.showAnnouncement(
      id: a.id,
      title: title,
      body: body,
      critical: priority == AnnouncementPriority.critical,
    );

    await load();
  }

  Future<void> markRead(int id) async {
    await _db.markAnnouncementRead(id);
    await load();
  }
}
