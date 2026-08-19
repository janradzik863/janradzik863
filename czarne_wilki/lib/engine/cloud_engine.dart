import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'ai_engine.dart';
import '../data/models.dart';

/// Silnik chmurowy zgodny z API OpenAI (/v1/chat/completions, stream SSE).
/// Obsługuje OpenRouter (w tym modele darmowe) oraz DeepSeek.
class CloudEngine implements AiEngine {
  CloudEngine({
    required ModelEntry model,
    Dio? dio,
  })  : _model = model,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 5),
              headers: {'Content-Type': 'application/json'},
            ));

  final ModelEntry _model;
  final Dio _dio;

  @override
  String get displayName => _model.displayName;

  @override
  bool get isLocal => false;

  @override
  Stream<String> chat({
    required String system,
    required List<(String role, String content)> turns,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async* {
    final url = '${_trimSlash(_model.baseUrl)}/chat/completions';
    final body = <String, Object?>{
      'model': _model.modelId,
      'stream': true,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'messages': [
        {'role': 'system', 'content': system},
        for (final t in turns)
          {'role': t.$1, 'content': t.$2},
      ],
    };

    final headers = <String, String>{
      'Authorization': 'Bearer ${_model.apiKey}',
    };
    // OpenRouter wymaga identyfikacji aplikacji.
    if ((_model.baseUrl ?? '').contains('openrouter')) {
      headers['HTTP-Referer'] = 'https://czarne-wilki.local';
      headers['X-Title'] = 'Czarne Wilki';
    }

    try {
      final response = await _dio.post<ResponseBody>(
        url,
        data: body,
        options: Options(headers: headers, responseType: ResponseType.stream),
      );

      final stream = response.data!.stream;
      yield* _parseSse(stream);
    } on DioException catch (e) {
      throw AiEngineException(
        'Błąd połączenia z dostawcą chmurowym: ${e.message}',
        userHint: 'Sprawdź klucz API, adres Base URL oraz tryb Sieciowy '
            '(w trybie Offline chmura jest niedostępna).',
      );
    }
  }

  /// Parser strumienia SSE: linie "data: {...}" z polami choices[].delta.
  Stream<String> _parseSse(Stream<List<int>> byteStream) async* {
    var buffer = <int>[];

    await for (final chunk in byteStream) {
      buffer.addAll(chunk);
      // Tnij po bajtach nowej linii; resztę trzymaj w buforze.
      var nl = buffer.indexOf(10);
      while (nl >= 0) {
        final lineBytes = buffer.sublist(0, nl);
        buffer = buffer.sublist(nl + 1);
        final line = utf8.decode(lineBytes, allowMalformed: true).trim();
        if (line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          if (payload == '[DONE]') return;
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map?;
              final text = delta?['content'];
              if (text is String && text.isNotEmpty) yield text;
            }
          } catch (_) {
            // Fragmenty nie-JSON (np. keep-alive) ignorujemy.
          }
        }
        nl = buffer.indexOf(10);
      }
    }
  }

  static String _trimSlash(String? s) =>
      (s ?? '').trim().replaceAll(RegExp(r'/+$'), '');
}
