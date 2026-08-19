import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Generowanie obrazów w trybie Sieciowym.
///
/// Wykorzystuje Pollinations.AI — darmową, otwartą usługę generowania
/// obrazów nie wymagającą klucza API. Uwaga: to usługa ZEWNĘTRZNA —
/// w trybie Offline moduł jest zablokowany (żadne żądanie nie wychodzi).
class ImageEngine {
  ImageEngine({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 5),
        ));

  final Dio _dio;

  Future<String> generate({
    required String prompt,
    int width = 1024,
    int height = 1024,
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final images = Directory('${dir.path}/images');
    if (!images.existsSync()) images.createSync(recursive: true);
    final name =
        'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = '${images.path}/$name';

    final url = Uri.parse(
      'https://image.pollinations.ai/prompt/${Uri.encodeComponent(prompt)}'
      '?width=$width&height=$height&nologo=true&seed=${DateTime.now().millisecondsSinceEpoch % 100000}',
    );

    try {
      await _dio.download(
        url.toString(),
        target,
        onReceiveProgress: (r, total) {
          if (total > 0) onProgress?.call(r / total);
        },
      );
      return target;
    } on DioException catch (e) {
      throw Exception('Nie udało się wygenerować obrazu: ${e.message}');
    }
  }
}
