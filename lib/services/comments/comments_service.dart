import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../llm_service.dart';

/// Komentarz pod opublikowanym postem (#18).
class Comment {
  final String id;
  final String postId;
  final String author;
  final String text;
  final DateTime createdAt;
  String? agentReply; // odpowiedź wygenerowana przez aktywnego agenta

  Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.text,
    required this.createdAt,
    this.agentReply,
  });

  bool get hasReply => agentReply != null && agentReply!.isNotEmpty;
}

/// Aktywny agent w sekcji komentarzy (#18).
///
/// Po publikacji posta agent monitoruje napływające komentarze i odpowiada
/// automatycznie (możliwość włączenia/wyłączenia oraz konfiguracji tonu).
class CommentsService extends ChangeNotifier {
  final LlmService _llm = LlmService();

  bool _autoReply = true;
  bool get autoReply => _autoReply;

  final List<Comment> _comments = [];
  List<Comment> get comments => List.unmodifiable(_comments);

  static const _prefAuto = 'comments.autoReply';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _autoReply = prefs.getBool(_prefAuto) ?? true;
    notifyListeners();
  }

  CommentsService() {
    _seed();
  }

  void _seed() {
    final now = DateTime.now();
    _comments.add(Comment(
      id: 'c1',
      postId: 'demo-1',
      author: 'Obserwator',
      text: 'Świetny post! Kiedy kolejny?',
      createdAt: now.subtract(const Duration(minutes: 30)),
    ));
  }

  Future<void> setAutoReply(bool v) async {
    _autoReply = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAuto, v);
  }

  /// Dodaje nowy komentarz; jeśli auto-reply włączone, agent odpowiada.
  Future<void> addComment({
    required String postId,
    required String author,
    required String text,
    required bool online,
    required String model,
  }) async {
    final c = Comment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      postId: postId,
      author: author,
      text: text,
      createdAt: DateTime.now(),
    );
    _comments.add(c);
    notifyListeners();

    if (_autoReply) {
      final reply = await _llm.raw(
        'Odpowiedz krótko i rzeczowo na komentarz użytkownika '
        '"$author" pod postem społeczności "Czarne Wilki Prawdy":\n'
        '"$text"',
        online: online,
        model: model,
      );
      c.agentReply = reply;
      notifyListeners();
    }
  }
}
