import 'package:flutter/services.dart';

/// Most do natywnego silnika llama.cpp (wymaganie #4, #19).
///
/// Na Androidzie wywołuje `NativeLlmEngine.kt` → JNI → llama.cpp (akceleracja
/// GPU przez Vulkan). Na platformach bez natywnego silnika zgłasza błąd.
class LocalInferenceService {
  static const MethodChannel _channel =
      MethodChannel('czarne_wilki/llm');

  bool _loaded = false;

  /// Ładuje model GGUF do pamięci (z raportowaniem postępu).
  Future<void> loadModel({
    required String path,
    int contextSize = 2048,
    int gpuLayers = -1,
  }) async {
    try {
      await _channel.invokeMethod('loadModel', {
        'path': path,
        'contextSize': contextSize,
        'gpuLayers': gpuLayers,
      });
      _loaded = true;
    } on MissingPluginException {
      throw StateError('Natywny silnik llama.cpp nie jest dostępny na tej platformie.');
    }
  }

  /// Generuje odpowiedź (tokeny) — pełna kontrola na urządzeniu (#19).
  Future<String> generate(String prompt) async {
    if (!_loaded) {
      throw StateError('Najpierw załaduj model (loadModel).');
    }
    final result = await _channel.invokeMethod<String>('generate', {
      'prompt': prompt,
    });
    return result ?? '';
  }

  /// Zatrzymuje generowanie (odpowiednik przycisku Stop, #2).
  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  Future<void> unload() async {
    await _channel.invokeMethod('unload');
    _loaded = false;
  }

  Future<bool> isLoaded() async => _loaded;
}
