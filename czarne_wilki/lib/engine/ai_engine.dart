/// Abstrakcja silnika konwersacji. Wspólny interfejs dla modelu lokalnego
/// (GGUF przez llama.cpp) i chmurowego (OpenAI-compatible: OpenRouter,
/// DeepSeek). Historia przekazywana jest w całości — każdy model czyta
/// ten sam kontekst z lokalnej bazy.
abstract class AiEngine {
  /// Krótka, ludzka nazwa silnika (do chipów w UI i logów).
  String get displayName;

  /// Czy silnik pracuje w pełni lokalnie na urządzeniu.
  bool get isLocal;

  /// Strumieniowana odpowiedź na historię rozmowy.
  ///
  /// [system] — prompt systemowy z profilu agenta (personalizacja).
  /// [turns]  — dotychczasowa rozmowa (bez komunikatu systemowego).
  Stream<String> chat({
    required String system,
    required List<(String role, String content)> turns,
    double temperature,
    int maxTokens,
  });

  /// Zwolnienie zasobów (kontekst modelu lokalnego, połączenia).
  Future<void> dispose() async {}

  /// Leniwe przygotowanie (załadowanie modelu lokalnego do pamięci).
  /// Silniki chmurowe nie muszą nadpisywać.
  Future<void> ensureReady() async {}

  /// Przerwanie trwającego generowania.
  Future<void> stopGeneration() async {}
}

class AiEngineException implements Exception {
  AiEngineException(this.message, {this.userHint});

  /// Opis techniczny.
  final String message;

  /// Podpowiedź dla użytkownika (co zrobić).
  final String? userHint;

  @override
  String toString() => message;
}
