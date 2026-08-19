import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Katalog lokalnych modeli GGUF (wymaganie #4).
///
/// Obsługuje pobieranie modeli z zewnętrznych repozytoriów (Hugging Face
/// i dowolne bezpośrednie URL-e) oraz listę modeli zainstalowanych lokalnie.
/// Modele przechowywane są w katalogu aplikacji — nigdy w chmurze.
class ModelRepository {
  static const _dirName = 'models';

  Future<Directory> _modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, _dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<String>> installedModels() async {
    final dir = await _modelsDir();
    final list = await dir.list().toList();
    return list
        .whereType<File>()
        .map((f) => f.path)
        .where((fp) => fp.endsWith('.gguf'))
        .toList();
  }

  /// Pobiera model GGUF z podanego URL z raportowaniem postępu.
  Future<String> download({
    required String url,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _modelsDir();
    final dest = p.join(dir.path, fileName);

    final req = http.Request('GET', Uri.parse(url));
    final client = http.Client();
    final streamed = await client.send(req);
    final total = streamed.contentLength ?? 0;

    final out = File(dest).openWrite();
    var received = 0;
    await for (final chunk in streamed.stream) {
      received += chunk.length;
      out.add(chunk);
      if (total > 0 && onProgress != null) {
        onProgress(received / total);
      }
    }
    await out.close();
    client.close();
    return dest;
  }
}
