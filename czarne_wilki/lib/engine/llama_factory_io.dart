import 'dart:async';
import 'dart:io' show Platform;

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Jedyny plik aplikacji importujący llama_cpp_dart bezpośrednio.
/// Przy zmianie API pakietu między wersjami poprawka dotyczy
/// wyłącznie tego pliku.
class LlamaParentHandle {
  LlamaParentHandle(this.path, this.chatFormat);

  final String path;
  final String chatFormat;

  LlamaParent? _parent;
  StreamSubscription<String>? _sub;

  /// Nazwa biblioteki natywnej zależna od platformy:
  /// Android/Linux → libllama.so, Windows → libllama.dll, macOS → .dylib.
  static String libraryName() {
    if (Platform.isWindows) return 'libllama.dll';
    if (Platform.isMacOS) return 'libllama.dylib';
    return 'libllama.so';
  }

  Future<void> init() async {
    Llama.libraryPath = libraryName();

    final format = switch (chatFormat) {
      'llama2' => Llama2ChatFormat(),
      'gemma' => GemmaChatFormat(),
      'mistral' => MistralChatFormat(),
      _ => ChatMLFormat(),
    };

    final load = LlamaLoad(
      path: path,
      modelParams: ModelParams(),
      contextParams: ContextParams(),
      samplingParams: SamplerParams(),
      format: format,
    );
    _parent = LlamaParent(load);
    await _parent!.init();
  }

  /// Rozmowa z pełną historią; strumień tokenów do UI.
  Stream<String> chat({
    required String system,
    required List<(String role, String content)> turns,
  }) async* {
    final parent = _parent;
    if (parent == null) return;

    // Historia przekazywana do wbudowanego formatera czatu pakietu.
    parent.messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      for (final t in turns.take(turns.length - 1))
        {'role': t.$1, 'content': t.$2},
    ];

    var streamed = false;
    final live = StreamController<String>();
    _sub = parent.stream.listen((token) {
      streamed = true;
      if (!live.isClosed) live.add(token);
    });

    String full = '';
    try {
      full = await parent.sendPrompt(turns.last.$2);
    } finally {
      await _sub?.cancel();
      _sub = null;
    }

    // Starsze wersje pakietu nie emitują strumienia — oddajemy całość.
    if (!streamed && full.isNotEmpty && !live.isClosed) {
      live.add(full);
    }
    await live.close();
    yield* live.stream;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _parent?.stop();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _parent?.dispose();
    _parent = null;
  }
}
