import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import 'ai_engine.dart';
import 'llama_factory_io.dart';

/// Lokalny silnik GGUF (llama.cpp przez llama_cpp_dart).
///
/// Wymaga biblioteki natywnej libllama.so skompilowanej dla arm64-v8a
/// (patrz tools/build_llama_android.sh) — bez niej silnik zgłasza
/// przyjazny błąd, a aplikacja działa dalej w trybie chmurowym.
class LocalEngine implements AiEngine {
  LocalEngine({required ModelEntry model}) : _model = model;

  final ModelEntry _model;
  LlamaParentHandle? _handle;

  @override
  String get displayName => _model.displayName;

  @override
  bool get isLocal => true;

  @override
  Future<void> ensureReady() async {
    if (_handle != null) return;

    if (!await probeLibrary()) {
      throw const AiEngineException(
        'Brak biblioteki natywnej libllama.so.',
        userHint: 'Lokalne modele wymagają biblioteki llama.cpp — uruchom '
            'tools/build_llama_android.sh i przebuduj APK. Do tego czasu '
            'korzystaj z modeli chmurowych (tryb Sieciowy).',
      );
    }
    final path = _model.filePath;
    if (path == null || !File(path).existsSync()) {
      throw AiEngineException(
        'Plik modelu nie istnieje: $path',
        userHint: 'Pobierz model GGUF ponownie w ekranie Modeli.',
      );
    }

    final handle = LlamaParentHandle(path, _model.chatFormat);
    await handle.init();
    _handle = handle;
    debugPrint('[LocalEngine] model załadowany: ${_model.displayName}');
  }

  @override
  Stream<String> chat({
    required String system,
    required List<(String role, String content)> turns,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async* {
    await ensureReady();
    if (turns.isEmpty) return;

    final handle = _handle!;
    yield* handle.chat(
      system: system,
      turns: turns,
    );
  }

  @override
  Future<void> stopGeneration() async => await _handle?.stop();

  @override
  Future<void> dispose() async {
    await _handle?.dispose();
    _handle = null;
  }

  /// Sprawdza obecność biblioteki natywnej llama.cpp (Android/Linux: .so,
  /// Windows: .dll, macOS: .dylib).
  static Future<bool> probeLibrary() async {
    final name = LlamaParentHandle.libraryName();
    if (Platform.isAndroid) {
      return await compute(_tryOpen, name);
    }
    return _tryOpen(name);
  }

  static bool _tryOpen(String lib) {
    try {
      DynamicLibrary.open(lib);
      return true;
    } catch (_) {
      return false;
    }
  }
}
