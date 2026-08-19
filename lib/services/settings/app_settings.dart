import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralny magazyn ustawień wszystkich modułów.
///
/// Jedno źródło prawdy dla konfiguracji, które nie mają własnego serwisu.
/// Trwałość: pojedynczy blob JSON w shared_preferences.
/// Ustawienia, które żyją we własnych serwisach (tryb online, model, głos,
/// personalizacja agenta, Telegram, auto-odpowiedzi komentarzy), są tam
/// odczytywane bezpośrednio — bez duplikacji stanu.
class AppSettings extends ChangeNotifier {
  static const _key = 'module_settings';

  static const Map<String, dynamic> _defaults = {
    // #1 Synchronizacja
    'syncEnabled': false,
    'syncRelay': '',
    // #2 Mikrofon / STT
    'sttLocale': 'pl-PL',
    // #3 Głosy (TTS)
    'ttsRate': 0.5,
    'ttsPitch': 1.0,
    'ttsVolume': 1.0,
    // #4 / #19 Modele lokalne
    'contextSize': 2048,
    'gpuLayers': -1,
    // #8 Agent automatyzacji
    'agentMaxSteps': 20,
    'agentStepDelayMs': 700,
    // #10 Asystent kodowania
    'coderLanguage': 'dart',
    // #11 Samonaprawa
    'dexPath': '',
    // #12 Komunikator
    'messengerRelay': '',
    // #13 Radio
    'radioRelay': '',
    // #16 Moderacja
    'moderationAutoApprove': false,
    // #17 Ogłoszenia
    'alertsEnabled': true,
    'announcementsEnabled': true,
  };

  Map<String, dynamic> _data = Map.from(_defaults);

  T get<T>(String key) => (_data[key] ?? _defaults[key]) as T;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _data = {..._defaults, ...decoded};
      } catch (_) {
        _data = Map.from(_defaults);
      }
    }
    notifyListeners();
  }

  Future<void> set(String key, dynamic value) async {
    _data[key] = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_data));
  }

  /// Wygodne settery dla konkretnych pól (typowe).
  Future<void> setBool(String key, bool v) => set(key, v);
  Future<void> setInt(String key, int v) => set(key, v);
  Future<void> setDouble(String key, double v) => set(key, v);
  Future<void> setString(String key, String v) => set(key, v);
}
