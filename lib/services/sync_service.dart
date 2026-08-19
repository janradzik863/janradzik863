import 'package:flutter/services.dart';

/// Most komunikacyjny między wersją Android a wersją desktop (#1).
///
/// W wersji produkcyjnej używa szyfrowanego kanału (WebRTC DataChannel /
/// Signal Protocol) do synchronizacji stanu w czasie rzeczywistym.
/// Na Androidzie jest uzupełniany o natywne powiadomienia (FCM/APE).
class SyncService {
  static const MethodChannel _channel =
      MethodChannel('czarne_wilki/sync');

  Future<void> sendEvent(String type, Map<String, dynamic> payload) async {
    try {
      await _channel.invokeMethod('sendEvent', {
        'type': type,
        'payload': payload,
      });
    } on PlatformException {
      // Brak natywnego mostu (desktop) — nie krytyczne.
    }
  }
}
