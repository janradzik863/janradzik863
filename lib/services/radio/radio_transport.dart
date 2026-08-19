import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Transport radia społecznościowego (wymaganie #13).
///
/// Kanał sygnalizacyjny to WebSocket: wymiana zdarzeń kolejki, synchronizacji
/// pozycji odtwarzania i obecności słuchaczy. Sam strumień audio idzie
/// peer-to-peer przez WebRTC (DataChannel / MediaStream) — bez pośredników.
///
/// Integracja WebRTC (patrz też docs/ARCHITECTURE.md):
///   1. dodaj `flutter_webrtc` do pubspec.yaml,
///   2. utwórz RTCPeerConnection per słuchacz i wynegocjuj SDP/ICE przez ten
///      kanał sygnalizacyjny (zdarzenia `offer`/`answer`/`candidate`),
///   3. strumień audio (MediaStreamTrack) rozsyłaj do połączonych peerów.
class RadioTransport {
  final void Function(Map<String, dynamic>) onEvent;
  WebSocket? _ws;

  RadioTransport(this.onEvent);

  Future<void> connect(String relayUrl) async {
    _ws = await WebSocket.connect(relayUrl);
    _ws!.listen((data) {
      try {
        onEvent(jsonDecode(data as String) as Map<String, dynamic>);
      } catch (_) {
        // ignoruj niepoprawne ramki
      }
    });
  }

  /// Wysyła zdarzenie sygnalizacyjne (join/queue/sync/offer/answer/candidate).
  void send(Map<String, dynamic> event) {
    _ws?.add(jsonEncode(event));
  }

  Future<void> dispose() async {
    await _ws?.close();
    _ws = null;
  }
}
