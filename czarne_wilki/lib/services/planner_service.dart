import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';

/// Punkt 7: Planer Publikacji z harmonogramem dat, godzin i platform.
class PlannerService extends ChangeNotifier {
  PlannerService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;
  List<PlannerPost> _posts = [];

  List<PlannerPost> get posts => _posts;

  List<PlannerPost> get drafts =>
      _posts.where((p) => p.status == PostStatus.draft).toList();
  List<PlannerPost> get scheduled =>
      _posts.where((p) => p.status == PostStatus.scheduled).toList();
  List<PlannerPost> get published =>
      _posts.where((p) => p.status == PostStatus.published).toList();

  Future<void> load() async {
    _posts = await _db.listPlannerPosts();
    notifyListeners();
  }

  Future<PlannerPost> createPost({
    required String title,
    required String content,
    required String platform,
    required DateTime scheduledAt,
    String? attachmentPath,
  }) async {
    final post = await _db.addPlannerPost(PlannerPost(
      id: 0,
      title: title,
      content: content,
      platform: platform,
      scheduledAt: scheduledAt,
      attachmentPath: attachmentPath,
    ));
    await load();
    return post;
  }

  /// Zatwierdź post do publikacji (pkt 16: wymaga moderacji).
  Future<void> approve(int id) async {
    final post = _posts.firstWhere((p) => p.id == id);
    await _db.updatePlannerPost(
      post.copyWith(approved: true, status: PostStatus.scheduled),
    );
    await load();
  }

  /// Oznacz jako opublikowany (po akcji automatyzacji).
  Future<void> markPublished(int id) async {
    final post = _posts.firstWhere((p) => p.id == id);
    await _db.updatePlannerPost(
      post.copyWith(status: PostStatus.published),
    );
    await load();
  }

  Future<void> deletePost(int id) async {
    await _db.deletePlannerPost(id);
    await load();
  }

  /// Posty gotowe do publikacji (zaakceptowane i pora minęła).
  List<PlannerPost> readyForPublishing() {
    final now = DateTime.now();
    return _posts
        .where((p) =>
            p.approved &&
            p.status == PostStatus.scheduled &&
            p.scheduledAt.isBefore(now))
        .toList();
  }
}
