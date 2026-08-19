import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Dostęp do repozytorium Hugging Face: wyszukiwanie publicznych
/// modeli GGUF i pobieranie ich na urządzenie z postępem.
class HfRepository {
  HfRepository({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(hours: 4),
        ));

  final Dio _dio;

  /// Katalog na modele GGUF (application-support/models).
  Future<Directory> modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/models');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Wyszukaj publiczne modele GGUF. Zwraca listę (repoId, liczba plików).
  Future<List<HfModel>> search(String query) async {
    final r = await _dio.get<List<dynamic>>(
      'https://huggingface.co/api/models',
      queryParameters: {
        'search': query,
        'filter': 'gguf',
        'sort': 'downloads',
        'direction': -1,
        'limit': 20,
      },
    );
    final out = <HfModel>[];
    for (final raw in r.data ?? const <dynamic>[]) {
      final m = raw as Map<String, dynamic>;
      out.add(HfModel(
        repoId: m['id'] as String,
        downloads: (m['downloads'] as num?)?.toInt() ?? 0,
        likes: (m['likes'] as num?)?.toInt() ?? 0,
      ));
    }
    return out;
  }

  /// Lista plików .gguf w repozytorium (endpoint "tree").
  Future<List<String>> listGgufFiles(String repoId) async {
    final r = await _dio.get<List<dynamic>>(
      'https://huggingface.co/api/models/$repoId/tree/main',
    );
    final files = <String>[];
    for (final raw in r.data ?? const <dynamic>[]) {
      final f = raw as Map<String, dynamic>;
      final path = f['path'] as String?;
      if (path != null && path.toLowerCase().endsWith('.gguf')) {
        files.add(path);
      }
    }
    return files;
  }

  /// Pobierz plik GGUF z postępem (callback 0.0–1.0).
  Future<String> download({
    required String repoId,
    required String filePath,
    required void Function(double progress) onProgress,
    void Function()? onCancelled,
  }) async {
    final dir = await modelsDir();
    final fileName =
        '${repoId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}__${filePath.split('/').last}';
    final target = '${dir.path}/$fileName';
    final url =
        'https://huggingface.co/$repoId/resolve/main/${filePath.replaceFirst(RegExp(r'^/'), '')}';

    final cancel = CancelToken();
    _activeCancels.add(cancel);
    try {
      await _dio.download(
        url,
        target,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received / total);
        },
        options: Options(
          // Serwer HF wysyła przekierowania do CDN — Dio je śledzi.
          followRedirects: true,
          maxRedirects: 5,
          headers: {HttpHeaders.acceptEncodingHeader: 'identity'},
        ),
      );
      return target;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        onCancelled?.call();
        // Usuwamy częściowy plik.
        final f = File(target);
        if (f.existsSync()) f.deleteSync();
        throw Exception('Pobieranie anulowane.');
      }
      rethrow;
    } finally {
      _activeCancels.remove(cancel);
    }
  }

  final List<CancelToken> _activeCancels = [];

  void cancelAll() {
    for (final c in _activeCancels.toList()) {
      if (!c.isCancelled) c.cancel();
    }
  }
}

class HfModel {
  HfModel({
    required this.repoId,
    required this.downloads,
    required this.likes,
  });

  final String repoId;
  final int downloads;
  final int likes;
}

/// Pomocnicze: odczyt rozmiaru pliku modelu na urządzeniu.
int modelFileSize(String path) {
  final f = File(path);
  if (!f.existsSync()) return 0;
  return f.lengthSync();
}

/// Skrót czytelny dla ludzi (GB/MB).
String humanSize(int bytes) {
  if (bytes <= 0) return '—';
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  return '${(bytes / mb).toStringAsFixed(0)} MB';
}
