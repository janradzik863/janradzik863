import '../../services/llm_service.dart';

/// Asystent kodowania (#10) — pisze nową logikę na życzenie użytkownika.
///
/// Generuje kod (Dart/Kotlin/inny) przez aktywny model AI, a na żądanie
/// wstrzykuje go w locie (Android: dynamiczne ładowanie klas, #11;
/// desktop: modyfikacja plików źródłowych).
class CoderService {
  final LlmService _llm = LlmService();

  /// Generuje kod na podstawie opisu zadania.
  Future<String> generateCode({
    required bool online,
    required String model,
    required String language,
    required String description,
  }) async {
    final prompt = 'Napisz kompletny, poprawny kod w języku $language '
        'realizujący następujące zadanie. Zwróć wyłącznie kod (bez opisu '
        'poza komentarzami w kodzie):\n\n$description';
    return _llm.raw(prompt, online: online, model: model);
  }

  /// Generuje nową logikę dla istniejącego kodu (refactor/rozszerzenie).
  Future<String> improveCode({
    required bool online,
    required String model,
    required String language,
    required String existingCode,
    required String instruction,
  }) async {
    final prompt = 'Oto istniejący kod w $language:\n\n$existingCode\n\n'
        'Zastosuj do niego następującą zmianę i zwróć cały poprawiony kod:\n'
        '$instruction';
    return _llm.raw(prompt, online: online, model: model);
  }
}
