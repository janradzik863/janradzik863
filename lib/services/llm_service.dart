import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'local_inference_service.dart';

/// Abstrakcja nad inferencją AI.
///
/// - tryb OFFLINE (#5): lokalny model GGUF przez natywny moduł (llama.cpp,
///   Vulkan) — wymaganie #4 i #19 (model otwarty, bez zewnętrznych filtrów).
/// - tryb ONLINE (#5): dostawca chmurowy (OpenRouter/DeepSeek/OpenAI).
///
/// Konfiguracja (klucz API / Base URL) jest współdzielona między wszystkimi
/// konsumentami (czat, asystent kodu, agent komentarzy) przez pola statyczne —
/// niezależnie od tego, ile instancji `LlmService` powstanie.
class LlmService {
  static String? apiKey;
  static String baseUrl = 'https://openrouter.ai/api/v1';

  /// Natywny silnik lokalny (llama.cpp) — używany w trybie offline (#4/#19).
  final LocalInferenceService local = LocalInferenceService();

  /// Czy model lokalny jest załadowany (do trybu offline).
  Future<bool> isLocalModelLoaded() => local.isLoaded();

  /// Wspólna konfiguracja (wołana z AppState przy starcie i po zmianie).
  static void configure({String? apiKey, String? baseUrl}) {
    if (apiKey != null) LlmService.apiKey = apiKey;
    if (baseUrl != null) LlmService.baseUrl = baseUrl;
  }

  Future<String> complete({
    required bool online,
    required String model,
    required AgentConfig agent,
    required List<Message> history,
  }) async {
    if (!online) {
      return _localInference(model, agent, history);
    }
    return _cloudInference(model, agent, history);
  }

  /// Lokalna inferencja — woła natywny silnik llama.cpp (Vulkan) (#4/#19).
  /// Model odpowiada tak, jak został wytrenowany — bez zewnętrznych filtrów.
  Future<String> _localInference(
    String model,
    AgentConfig agent,
    List<Message> history,
  ) async {
    try {
      final prompt = _buildChatPrompt(agent, history);
      return await local.generate(prompt);
    } catch (_) {
      return '[offline] Model lokalny nie jest załadowany. '
          'Załaduj plik GGUF w sekcji "Modele lokalne" (wymaganie #4).';
    }
  }

  String _buildChatPrompt(AgentConfig agent, List<Message> history) {
    final buf = StringBuffer();
    buf.writeln(agent.systemPrompt);
    for (final m in history.takeLast(20)) {
      final who = m.role == MessageRole.user
          ? 'Użytkownik'
          : (m.role == MessageRole.assistant ? 'Asystent' : 'System');
      buf.writeln('$who: ${m.content}');
    }
    buf.writeln('Asystent:');
    return buf.toString();
  }

  /// Generuje odpowiedź na surowy prompt (bez szablonu czatu) — używane m.in.
  /// przez asystenta kodowania (#10).
  Future<String> raw(
    String prompt, {
    required bool online,
    required String model,
  }) async {
    if (!online) {
      try {
        return await local.generate(prompt);
      } catch (_) {
        return '[offline] Model lokalny nie jest załadowany. '
            'Załaduj plik GGUF w sekcji "Modele lokalne" (wymaganie #4).';
      }
    }
    final resp = await http.post(
      Uri.parse('${LlmService.baseUrl}/chat/completions'),
      headers: _headers(),
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );
    if (resp.statusCode != 200) return '[błąd ${resp.statusCode}]';
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = data['choices'] as List? ?? [];
    if (choices.isEmpty) return '[brak odpowiedzi]';
    final msg = (choices.first as Map)['message'] as Map;
    return msg['content'] as String? ?? '[pusty]';
  }

  /// Inferencja chmurowa przez OpenRouter (format zgodny z OpenAI).
  Future<String> _cloudInference(
    String model,
    AgentConfig agent,
    List<Message> history,
  ) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': agent.systemPrompt},
      for (final m in history.takeLast(20))
        {
          'role': m.role == MessageRole.user
              ? 'user'
              : (m.role == MessageRole.assistant ? 'assistant' : 'system'),
          'content': m.content,
        },
    ];

    final resp = await http.post(
      Uri.parse('${LlmService.baseUrl}/chat/completions'),
      headers: _headers(),
      body: jsonEncode({'model': model, 'messages': messages}),
    );

    if (resp.statusCode != 200) {
      return '[błąd ${resp.statusCode}] ${resp.body}';
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = data['choices'] as List? ?? [];
    if (choices.isEmpty) return '[brak odpowiedzi]';
    final msg = (choices.first as Map)['message'] as Map;
    return msg['content'] as String? ?? '[pusty]';
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (LlmService.apiKey != null && LlmService.apiKey!.isNotEmpty)
          'Authorization': 'Bearer ${LlmService.apiKey}',
      };
}
