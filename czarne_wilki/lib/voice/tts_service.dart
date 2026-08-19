import 'package:flutter_tts/flutter_tts.dart';

import '../data/app_database.dart';
import '../data/models.dart';

/// Biblioteka głosów: przeglądanie, odsłuch próbki i przełączanie głosu,
/// którym agent mówi. Działa na natywnym silniku TTS Androida —
/// wszystkie głosy zainstalowane na urządzeniu są dostępne lokalnie.
class TtsService {
  TtsService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;
  final FlutterTts _tts = FlutterTts();

  static const _kVoiceName = 'tts_voice_name';
  static const _kRate = 'tts_rate';
  static const _kPitch = 'tts_pitch';

  List<TtsVoice> _voices = [];
  String? _activeVoice;
  double _rate = 1.0;
  double _pitch = 1.0;
  bool _speaking = false;

  List<TtsVoice> get voices => _voices;

  /// Głosy z językiem polskim na początku listy.
  List<TtsVoice> get voicesPolishFirst {
    final pl = _voices.where((v) => v.isPolish).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final rest = _voices.where((v) => !v.isPolish).toList()
      ..sort((a, b) => a.locale.compareTo(b.locale));
    return [...pl, ...rest];
  }

  String? get activeVoice => _activeVoice;
  double get rate => _rate;
  double get pitch => _pitch;
  bool get speaking => _speaking;

  /// Inicjalizacja: wczytaj listę głosów i zapisane preferencje.
  Future<void> init() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('pl-PL');

    final raw = await _tts.getVoices;
    _voices = [
      for (final v in (raw as List).cast<Map<dynamic, dynamic>>())
        TtsVoice(
          name: (v['name'] ?? '?').toString(),
          locale: (v['locale'] ?? '').toString(),
          isDefault: false,
        ),
    ];

    _activeVoice = await _db.getSetting(_kVoiceName);
    _rate = double.tryParse(await _db.getSetting(_kRate) ?? '') ?? 1.0;
    _pitch = double.tryParse(await _db.getSetting(_kPitch) ?? '') ?? 1.0;
    await _applySettings();
  }

  Future<void> _applySettings() async {
    await _tts.setLanguage('pl-PL');
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    if (_activeVoice != null) {
      await _tts.setVoice({'name': _activeVoice, 'locale': 'pl-PL'});
    }
  }

  /// Odsłuch próbki głosu (bez zmiany wyboru).
  Future<void> preview(TtsVoice voice) async {
    await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    await _tts.setLanguage(voice.locale);
    _speaking = true;
    await _tts.speak(
        'Czarne Wilki. To jest próbka głosu ${voice.name}.');
    await _tts.setLanguage('pl-PL');
    if (_activeVoice != null) {
      await _tts.setVoice({'name': _activeVoice, 'locale': 'pl-PL'});
    }
    _speaking = false;
  }

  /// Wybór głosu agenta (zapisywany trwale).
  Future<void> select(TtsVoice voice) async {
    _activeVoice = voice.name;
    await _db.setSetting(_kVoiceName, voice.name);
    await _applySettings();
  }

  Future<void> setRate(double value) async {
    _rate = value;
    await _db.setSetting(_kRate, value.toString());
    await _tts.setSpeechRate(value);
  }

  Future<void> setPitch(double value) async {
    _pitch = value;
    await _db.setSetting(_kPitch, value.toString());
    await _tts.setPitch(value);
  }

  /// Odczytaj tekst aktywnym głosem.
  Future<void> speak(String text) async {
    await _applySettings();
    _speaking = true;
    await _tts.speak(text);
    _speaking = false;
  }

  /// Przerwij mówienie.
  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
  }
}
