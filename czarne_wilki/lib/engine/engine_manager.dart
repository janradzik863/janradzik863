import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import 'ai_engine.dart';
import 'cloud_engine.dart';
import 'local_engine.dart';

/// Zarządza wyborem silnika AI zgodnie z trybem pracy:
///  - Tryb Offline   → wyłącznie model lokalny (zero połączeń sieciowych).
///  - Tryb Sieciowy  → aktywny model użytkownika (chmura lub lokalny).
class EngineManager extends ChangeNotifier {
  EngineManager({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;

  static const _kNetMode = 'net_mode'; // 'online' | 'offline'

  AiEngine? _engine;
  ModelEntry? _activeModel;
  bool _online = true;

  AiEngine? get engine => _engine;
  ModelEntry? get activeModel => _activeModel;
  bool get online => _online;

  /// W trybie offline chmura jest całkowicie zablokowana.
  bool get cloudAllowed => _online;

  Future<void> load() async {
    final mode = await _db.getSetting(_kNetMode);
    _online = mode != 'offline';
    await _rebuild();
  }

  Future<void> setOnline(bool value) async {
    _online = value;
    await _db.setSetting(_kNetMode, value ? 'online' : 'offline');
    await _rebuild();
  }

  /// Przełączenie aktywnego modelu (z ekranu Modeli).
  Future<void> activate(ModelEntry model) async {
    await _db.activateModel(model.id);
    await _rebuild();
  }

  Future<void> _rebuild() async {
    await _engine?.dispose();
    _engine = null;

    _activeModel = await _db.activeModel();
    final m = _activeModel;
    if (m == null) return;

    if (m.source == ModelSource.cloud) {
      if (!_online) {
        // Offline: chmura niedostępna — silnik celowo nieaktywny.
        _engine = null;
      } else {
        _engine = CloudEngine(model: m);
      }
    } else {
      _engine = LocalEngine(model: m);
    }
    notifyListeners();
  }

  /// Czy lokalne wnioskowanie jest technicznie możliwe (biblioteka + model).
  Future<bool> localReady() async => await LocalEngine.probeLibrary();

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }
}
