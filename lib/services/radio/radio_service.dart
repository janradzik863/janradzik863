import 'package:flutter/foundation.dart';

import 'radio_transport.dart';

enum RadioState { idle, playing, paused, buffering }

/// Utwór w kolejce radia.
class Track {
  final String id;
  final String title;
  final String artist;
  final int durationMs; // 0 = live / nieznane
  final String? sourceUrl;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    this.durationMs = 0,
    this.sourceUrl,
  });
}

/// Wspólne radio społecznościowe (wymaganie #13).
///
/// Zarządza kolejką audio i synchronizuje pozycję odtwarzania dla wszystkich
/// słuchaczy w czasie rzeczywistym (wspólny zegar serwera + offset).
class RadioService extends ChangeNotifier {
  final List<Track> _queue = [];
  Track? _current;
  RadioState _state = RadioState.idle;
  int _listeners = 1;

  // Synchronizacja pozycji odtwarzania.
  int _clockOffsetMs = 0; // zegar serwera - zegar lokalny
  int _startPositionMs = 0;
  int? _trackStartServerMs;

  RadioTransport? _transport;

  List<Track> get queue => List.unmodifiable(_queue);
  Track? get current => _current;
  RadioState get state => _state;
  int get listeners => _listeners;
  bool get isPlaying => _state == RadioState.playing;

  /// Pozycja odtwarzania zsynchronizowana ze wspólnym zegarem (ms).
  int get syncedPositionMs {
    if (_state == RadioState.playing &&
        _current != null &&
        _trackStartServerMs != null) {
      final nowServer =
          DateTime.now().millisecondsSinceEpoch + _clockOffsetMs;
      final pos = _startPositionMs + (nowServer - _trackStartServerMs!);
      final dur = _current!.durationMs;
      return (dur > 0) ? pos % dur : pos;
    }
    return _startPositionMs;
  }

  /// Wstępna kolejka (demo). W produkcji kolejka pochodzi z serwera/peerów.
  void seed() {
    _queue.addAll([
      Track(
          id: '1',
          title: 'Husaria',
          artist: 'Czarne Wilki',
          durationMs: 210000),
      Track(
          id: '2',
          title: 'Prawda idzie z nami',
          artist: 'Czarne Wilki',
          durationMs: 185000),
    ]);
    _current = _queue.first;
    notifyListeners();
  }

  Future<void> connect(String relayUrl) async {
    _transport = RadioTransport(_onEvent);
    await _transport!.connect(relayUrl);
    _transport!.send({'type': 'join'});
  }

  void _onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'sync':
        _clockOffsetMs =
            (e['serverClock'] as int) - DateTime.now().millisecondsSinceEpoch;
        _startPositionMs = e['positionMs'] as int? ?? 0;
        _trackStartServerMs = e['serverClock'] as int;
        _listeners = e['listeners'] as int? ?? _listeners;
        notifyListeners();
        break;
      case 'queue':
        // Łączenie kolejki z peerów/serwera (lista id utworów).
        final ids = (e['queue'] as List?)?.cast<String>() ?? const [];
        final merged = ids
            .map((id) => _queue.where((t) => t.id == id).toList())
            .where((l) => l.isNotEmpty)
            .map((l) => l.first)
            .toList();
        if (merged.isNotEmpty) {
          _queue
            ..clear()
            ..addAll(merged);
          if (!merged.contains(_current)) _current = merged.first;
          notifyListeners();
        }
        break;
      default:
        break;
    }
  }

  // --- Sterowanie odtwarzaniem ---

  void addTrack(Track t) {
    _queue.add(t);
    _broadcastQueue();
    notifyListeners();
  }

  void play() {
    if (_current == null && _queue.isNotEmpty) _current = _queue.first;
    if (_current == null) return;
    _state = RadioState.playing;
    _trackStartServerMs =
        DateTime.now().millisecondsSinceEpoch + _clockOffsetMs;
    notifyListeners();
  }

  void pause() {
    _startPositionMs = syncedPositionMs;
    _trackStartServerMs = null;
    _state = RadioState.paused;
    notifyListeners();
  }

  void next() {
    if (_queue.isEmpty) return;
    final i = _queue.indexOf(_current!) + 1;
    _current = _queue[i % _queue.length];
    _startPositionMs = 0;
    _trackStartServerMs =
        _state == RadioState.playing
            ? DateTime.now().millisecondsSinceEpoch + _clockOffsetMs
            : null;
    notifyListeners();
  }

  void prev() {
    if (_queue.isEmpty) return;
    final i = _queue.indexOf(_current!) - 1;
    _current = _queue[(i + _queue.length) % _queue.length];
    _startPositionMs = 0;
    _trackStartServerMs =
        _state == RadioState.playing
            ? DateTime.now().millisecondsSinceEpoch + _clockOffsetMs
            : null;
    notifyListeners();
  }

  void _broadcastQueue() {
    _transport?.send({
      'type': 'queue',
      'queue': _queue.map((t) => t.id).toList(),
    });
  }
}
