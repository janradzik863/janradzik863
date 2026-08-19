import 'package:flutter/foundation.dart';

import '../../data/models.dart';

enum ItemStatus { pending, approved, rejected }

/// Materiał oczekujący na zatwierdzenie przed wydaniem (#16, #22).
class PendingItem {
  final String id;
  final String title;
  final String content;
  final ContentKind kind;
  final String author;
  final DateTime createdAt;
  ItemStatus status;

  PendingItem({
    required this.id,
    required this.title,
    required this.content,
    required this.kind,
    required this.author,
    required this.createdAt,
    this.status = ItemStatus.pending,
  });
}

/// Kolejka nadzoru i moderacji treści (wymaganie #16).
///
/// Rolę „głównego kontrolera jakości" (#22) pełni zatwierdzający
/// (administrator/moderator) — żaden materiał nie wychodzi bez akceptacji.
class ModerationService extends ChangeNotifier {
  final List<PendingItem> _queue = [];

  List<PendingItem> get queue => List.unmodifiable(_queue);
  List<PendingItem> get pending =>
      _queue.where((i) => i.status == ItemStatus.pending).toList();

  ModerationService() {
    _seedDemo();
  }

  void _seedDemo() {
    final now = DateTime.now();
    _queue.addAll([
      PendingItem(
        id: 'demo-1',
        title: 'Post: „Wszyscy Won!"',
        content: 'Treść posta oczekująca na zatwierdzenie…',
        kind: ContentKind.text,
        author: 'Czarny Wilk',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      PendingItem(
        id: 'demo-2',
        title: 'Grafika promocyjna',
        content: 'Obraz husarsko-wilczy do publikacji.',
        kind: ContentKind.image,
        author: 'Redaktor',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ]);
  }

  /// Dodaje materiał do kolejki (np. z czatu / generatora #6).
  void submit(PendingItem item) {
    _queue.add(item);
    notifyListeners();
  }

  void approve(String id) => _setStatus(id, ItemStatus.approved);
  void reject(String id) => _setStatus(id, ItemStatus.rejected);

  void _setStatus(String id, ItemStatus s) {
    final i = _queue.firstWhere((e) => e.id == id);
    i.status = s;
    notifyListeners();
  }
}
