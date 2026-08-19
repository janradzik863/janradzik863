import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import '../engine/ai_engine.dart';
import 'moderation_service.dart';

/// Punkt 18: Aktywny agent w sekcji komentarzy.
/// Generuje odpowiedzi na komentarze pod postami i wysyła je
/// do kolejki moderacji (pkt 22) przed opublikowaniem.
class CommentAgentService extends ChangeNotifier {
  CommentAgentService({
    AppDatabase? db,
    ModerationService? moderation,
  })  : _db = db ?? AppDatabase(),
        _moderation = moderation ?? ModerationService();

  final AppDatabase _db;
  final ModerationService _moderation;
  List<CommentAgentLog> _logs = [];
  bool _active = false;

  List<CommentAgentLog> get logs => _logs;
  bool get active => _active;

  Future<void> load() async {
    _logs = await _db.listCommentLogs();
    notifyListeners();
  }

  /// Generuj odpowiedź na komentarz pod postem.
  /// Odpowiedź NIE jest publikowana bezpośrednio — trafia do kolejki
  /// moderacji (pkt 22: kontroler jakości).
  Future<String?> generateReply({
    required AiEngine engine,
    required int postId,
    required String platform,
    required String originalComment,
    required String postContent,
  }) async {
    _active = true;
    notifyListeners();

    try {
      final buffer = StringBuffer();
      await for (final chunk in engine.chat(
        system: 'Jesteś asystentem odpowiadającym na komentarze pod postami '
            'projektu Czarne Wilki Prawdy. Odpowiadasz po polsku, krótko, '
            'konkretnie i z szacunkiem. Twoim celem jest merytoryczna '
            'dyskusja — nie eskalacja.',
        turns: [
          (
            'user',
            'Post na platformie $platform:\n"$postContent"\n\n'
                'Komentarz użytkownika:\n"$originalComment"\n\n'
                'Wygeneruj krótką, merytoryczną odpowiedź.',
          ),
        ],
        temperature: 0.5,
        maxTokens: 300,
      )) {
        buffer.write(chunk);
      }

      final reply = buffer.toString().trim();

      // Zaloguj
      await _db.addCommentLog(CommentAgentLog(
        id: 0,
        postId: postId,
        platform: platform,
        commentText: reply,
        status: 'pending_review',
      ));

      // Wyślij do moderacji (pkt 22: kontroler jakości)
      await _moderation.submitForReview(
        contentType: 'comment',
        content: reply,
        sourceId: postId,
        submittedBy: 'comment_agent',
      );

      await load();
      return reply;
    } catch (e) {
      debugPrint('[CommentAgent] Error: $e');
      return null;
    } finally {
      _active = false;
      notifyListeners();
    }
  }
}
