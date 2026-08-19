import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// Zapis/odczyt pliku kopii zapasowej — platformowo:
///  - Android: systemowy dialog SAF (kanał cw/files → Kotlin),
///  - desktop:  natywne dialogi file_picker.
class FilesService {
  static const MethodChannel _ch = MethodChannel('cw/files');

  /// Zapisuje treść do pliku wybranego przez użytkownika.
  /// Zwraca ścieżkę/URI zapisu albo null (anulowano).
  Future<String?> saveTextFile({
    required String fileName,
    required String content,
  }) async {
    if (Platform.isAndroid) {
      try {
        return await _ch.invokeMethod<String>('saveBackup', {
          'fileName': fileName,
          'content': content,
        });
      } on PlatformException catch (e) {
        if (e.code == 'CANCELLED') return null;
        rethrow;
      }
    }
    // Desktop: natywny dialog „Zapisz jako”.
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Zapisz kopię zapasową Czarne Wilki',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return null;
    File(path).writeAsStringSync(content);
    return path;
  }

  /// Wybiera i wczytuje plik kopii. Zwraca treść albo null (anulowano).
  Future<String?> pickTextFile() async {
    if (Platform.isAndroid) {
      try {
        return await _ch.invokeMethod<String>('pickBackup');
      } on PlatformException catch (e) {
        if (e.code == 'CANCELLED') return null;
        rethrow;
      }
    }
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Wybierz plik kopii zapasowej',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = res.files.single.path;
    if (path == null) return null;
    return File(path).readAsStringSync();
  }
}
