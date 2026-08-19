import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import '../engine/ai_engine.dart';

/// Punkt 10: Wbudowany Asystent Kodowania.
/// Punkt 11: Mechanizm samonaprawy i iniekcji kodu w locie.
class CodeAssistantService extends ChangeNotifier {
  CodeAssistantService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;
  List<CodeSnippet> _snippets = [];
  String _output = '';
  bool _busy = false;

  List<CodeSnippet> get snippets => _snippets;
  String get output => _output;
  bool get busy => _busy;

  Future<void> load() async {
    _snippets = await _db.listCodeSnippets();
    notifyListeners();
  }

  /// Generuj kod za pomocą aktywnego silnika AI.
  Future<String> generateCode({
    required AiEngine engine,
    required String request,
    String language = 'dart',
  }) async {
    _busy = true;
    _output = '';
    notifyListeners();

    try {
      final buffer = StringBuffer();
      await for (final chunk in engine.chat(
        system: 'Jesteś ekspertem programistą. Generujesz WYŁĄCZNIE kod '
            'w języku $language. Odpowiadasz samym kodem bez dodatkowych '
            'wyjaśnień. Kod musi być kompletny i gotowy do uruchomienia.',
        turns: [('user', request)],
        temperature: 0.3,
        maxTokens: 4096,
      )) {
        buffer.write(chunk);
        _output = buffer.toString();
        notifyListeners();
      }

      // Zapisz snippet do historii
      final snippet = await _db.addCodeSnippet(CodeSnippet(
        id: 0,
        title: request.length > 60 ? '${request.substring(0, 60)}…' : request,
        language: language,
        code: buffer.toString(),
      ));
      _snippets.insert(0, snippet);

      return buffer.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Punkt 11: Zapisz wygenerowany kod do pliku na urządzeniu.
  /// Na desktopie: zapisuje do katalogu projektu (modyfikacja źródeł).
  /// Na Androidzie: zapisuje do katalogu aplikacji (do dynamicznego załadowania).
  Future<String> saveCodeToFile(String code, String filename) async {
    final dir = await getApplicationSupportDirectory();
    final codeDir = Directory('${dir.path}/generated_code');
    if (!codeDir.existsSync()) codeDir.createSync(recursive: true);

    final file = File('${codeDir.path}/$filename');
    await file.writeAsString(code);
    debugPrint('[CodeAssistant] Zapisano: ${file.path}');
    return file.path;
  }

  /// Punkt 11: Próba samonaprawy — jeśli kod się nie kompiluje,
  /// wyślij błąd do AI i poproś o poprawkę.
  Future<String> selfRepair({
    required AiEngine engine,
    required String brokenCode,
    required String errorMessage,
    String language = 'dart',
  }) async {
    return generateCode(
      engine: engine,
      request: 'Napraw ten kod w języku $language. '
          'Oryginalny kod:\n```\n$brokenCode\n```\n\n'
          'Błąd kompilacji/uruchomienia:\n$errorMessage\n\n'
          'Zwróć TYLKO poprawiony kod bez wyjaśnień.',
      language: language,
    );
  }
}
