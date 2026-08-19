import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import 'sync_bridge.dart';

/// Punkt 13: Wspólne Radio Społecznościowe.
/// Strumieniowanie i synchronizacja kolejki audio dla wszystkich
/// słuchaczy w czasie rzeczywistym (przez SyncBridge).
class RadioService extends ChangeNotifier {
  RadioService({
    AppDatabase? db,
    SyncBridge? syncBridge,
  })  : _db = db ?? AppDatabase(),
        _sync = syncBridge;

  final AppDatabase _db;
  final SyncBridge? _sync;

  List<RadioTrack> _tracks = [];
  List<RadioTrack> _queue = [];
  int _currentIndex = -1;
  bool _playing = false;
  StreamSubscription? _syncSub;

  List<RadioTrack> get tracks => _tracks;
  List<RadioTrack> get queue => _queue;
  RadioTrack? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null;
  bool get playing => _playing;
  int get currentIndex => _currentIndex;

  Future<void> load() async {
    _tracks = await _db.listRadioTracks();
    notifyListeners();

    // Nasłuchuj synchronizacji z innymi urządzeniami
    _syncSub?.cancel();
    _syncSub = _sync?.onMessage.listen(_handleSyncMessage);
  }

  /// Dodaj utwór do biblioteki.
  Future<void> addTrack({
    required String title,
    required String filePath,
    String artist = '',
    int durationMs = 0,
  }) async {
    await _db.addRadioTrack(RadioTrack(
      id: 0,
      title: title,
      filePath: filePath,
      artist: artist,
      durationMs: durationMs,
    ));
    await load();
  }

  /// Dodaj do kolejki odtwarzania.
  void enqueue(RadioTrack track) {
    _queue.add(track);
    _broadcastQueue();
    notifyListeners();
  }

  /// Graj kolejny utwór.
  void play() {
    if (_queue.isEmpty) return;
    if (_currentIndex < 0) _currentIndex = 0;
    _playing = true;
    _broadcastState();
    notifyListeners();
  }

  void pause() {
    _playing = false;
    _broadcastState();
    notifyListeners();
  }

  void next() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _playing = true;
      _broadcastState();
      notifyListeners();
    }
  }

  void previous() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _playing = true;
      _broadcastState();
      notifyListeners();
    }
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
    _playing = false;
    _broadcastState();
    notifyListeners();
  }

  // ---- Synchronizacja z innymi urządzeniami ----

  void _broadcastState() {
    _sync?.send(SyncMessage(
      type: 'radio_state',
      payload: {
        'playing': _playing,
        'currentIndex': _currentIndex,
        'queueTitles': _queue.map((t) => t.title).toList(),
      },
    ));
  }

  void _broadcastQueue() {
    _sync?.send(SyncMessage(
      type: 'radio_queue',
      payload: {
        'tracks': _queue.map((t) => {
              'title': t.title,
              'artist': t.artist,
              'filePath': t.filePath,
            }).toList(),
      },
    ));
  }

  void _handleSyncMessage(SyncMessage msg) {
    if (msg.type == 'radio_state') {
      _playing = msg.payload['playing'] as bool? ?? false;
      _currentIndex = msg.payload['currentIndex'] as int? ?? -1;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }
}
