import 'package:flutter/services.dart';

/// Most do natywnego mikrofonu (AudioRecord) — ciągły nasłuch (#2).
class MicService {
  static const MethodChannel _channel = MethodChannel('czarne_wilki/mic');

  /// Rozpoczyna ciągły nasłuch (bez autozatrzymywania).
  Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false; // desktop: brak natywnego mikrofonu
    }
  }

  /// Zatrzymuje nasłuch (jawne Stop — wymaganie #2).
  Future<bool> stop() async {
    try {
      return await _channel.invokeMethod<bool>('stop') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> isRecording() async {
    try {
      return await _channel.invokeMethod<bool>('isRecording') ?? false;
    } catch (_) {
      return false;
    }
  }
}
