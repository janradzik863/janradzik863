import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';

/// Punkt 16 + 22: Panel moderacji treści z kontrolerem jakości.
/// Każdy materiał wygenerowany przez agenta trafia do kolejki moderacji
/// i wymaga zatwierdzenia przed opublikowaniem.
class ModerationService extends ChangeNotifier {
  ModerationService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;
  List<ModerationItem> _queue = [];
  int _pendingCount = 0;

  List<ModerationItem> get queue => _queue;
  int get pendingCount => _pendingCount;

  Future<void> refresh() async {
    _queue = await _db.listModerationQueue();
    _pendingCount = _queue.where((i) => i.status == ModerationStatus.pending).length;
    notifyListeners();
  }

  /// Pkt 22: Kontroler jakości — wyślij materiał do kolejki zatwierdzania.
  Future<ModerationItem> submitForReview({
    required String contentType,
    required String content,
    int? sourceId,
    String submittedBy = 'agent',
  }) async {
    final item = await _db.addModerationItem(ModerationItem(
      id: 0,
      contentType: contentType,
      content: content,
      sourceId: sourceId,
      submittedBy: submittedBy,
    ));
    await refresh();
    return item;
  }

  /// Zatwierdź materiał (admin/moderator).
  Future<void> approve(int id, String reviewer) async {
    final item = _queue.firstWhere((i) => i.id == id);
    final updated = item.copyWith(
      status: ModerationStatus.approved,
      reviewer: reviewer,
      reviewedAt: DateTime.now(),
    );
    await _db.updateModerationItem(updated);
    await refresh();
  }

  /// Odrzuć materiał.
  Future<void> reject(int id, String reviewer) async {
    final item = _queue.firstWhere((i) => i.id == id);
    final updated = item.copyWith(
      status: ModerationStatus.rejected,
      reviewer: reviewer,
      reviewedAt: DateTime.now(),
    );
    await _db.updateModerationItem(updated);
    await refresh();
  }

  /// Filtruj kolejkę.
  List<ModerationItem> filterByStatus(ModerationStatus status) =>
      _queue.where((i) => i.status == status).toList();
}
