import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Punkt 1: Most komunikacyjny do synchronizacji w czasie rzeczywistym
/// między wersją mobilną Android a wersją desktopową.
///
/// Architektura: prosty serwer WebSocket na jednym urządzeniu
/// (desktop = serwer, telefon = klient lub odwrotnie).
/// Dane przesyłane JSON: {type, payload}.
class SyncBridge extends ChangeNotifier {
  SyncBridge();

  HttpServer? _server;
  WebSocket? _client;
  final List<WebSocket> _connections = [];
  bool _isServer = false;
  bool _connected = false;
  String _statusText = 'Rozłączony';

  bool get isServer => _isServer;
  bool get connected => _connected;
  String get statusText => _statusText;

  final _msgCtrl = StreamController<SyncMessage>.broadcast();
  Stream<SyncMessage> get onMessage => _msgCtrl.stream;

  /// Uruchom jako serwer (desktopy lub telefon-host).
  Future<void> startServer({int port = 9876}) async {
    await stop();
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isServer = true;
      _connected = true;
      _statusText = 'Serwer nasłuchuje na porcie $port';
      notifyListeners();

      _server!.transform(WebSocketTransformer()).listen(
        (ws) {
          _connections.add(ws);
          _statusText = 'Połączono (${_connections.length} klientów)';
          notifyListeners();
          ws.listen(
            (data) => _handleIncoming(data as String),
            onDone: () {
              _connections.remove(ws);
              _statusText = _connections.isEmpty
                  ? 'Serwer — brak klientów'
                  : 'Połączono (${_connections.length})';
              notifyListeners();
            },
          );
        },
        onError: (e) {
          debugPrint('[SyncBridge] Server error: $e');
        },
      );
    } catch (e) {
      _statusText = 'Błąd serwera: $e';
      _connected = false;
      notifyListeners();
    }
  }

  /// Połącz jako klient do serwera drugiego urządzenia.
  Future<void> connectToServer(String host, {int port = 9876}) async {
    await stop();
    try {
      _client = await WebSocket.connect('ws://$host:$port');
      _isServer = false;
      _connected = true;
      _statusText = 'Połączono z $host:$port';
      notifyListeners();

      _client!.listen(
        (data) => _handleIncoming(data as String),
        onDone: () {
          _connected = false;
          _statusText = 'Rozłączono';
          notifyListeners();
        },
      );
    } catch (e) {
      _statusText = 'Nie udało się połączyć: $e';
      _connected = false;
      notifyListeners();
    }
  }

  void _handleIncoming(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final msg = SyncMessage(
        type: map['type'] as String,
        payload: map['payload'] as Map<String, dynamic>? ?? {},
      );
      _msgCtrl.add(msg);
    } catch (e) {
      debugPrint('[SyncBridge] Parse error: $e');
    }
  }

  /// Wyślij wiadomość synchronizacyjną do drugiego urządzenia.
  void send(SyncMessage msg) {
    final json = jsonEncode({'type': msg.type, 'payload': msg.payload});
    if (_isServer) {
      for (final ws in _connections) {
        ws.add(json);
      }
    } else {
      _client?.add(json);
    }
  }

  Future<void> stop() async {
    for (final ws in _connections) {
      await ws.close();
    }
    _connections.clear();
    await _client?.close();
    _client = null;
    await _server?.close();
    _server = null;
    _connected = false;
    _statusText = 'Rozłączony';
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _msgCtrl.close();
    super.dispose();
  }
}

class SyncMessage {
  SyncMessage({required this.type, this.payload = const {}});
  final String type;
  final Map<String, dynamic> payload;
}
