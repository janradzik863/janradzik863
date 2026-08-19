import 'package:flutter_tts/flutter_tts.dart';

import '../data/models.dart';

/// Biblioteka głosów AI (wymaganie #3): lista, odsłuch, przełączanie.
class VoiceService {
  final FlutterTts _tts = FlutterTts();

  /// Konfiguracja TTS (synchronizowana z AppSettings).
  static double rate = 0.5;
  static double pitch = 1.0;
  static double volume = 1.0;

  static void configure({double? rate, double? pitch, double? volume}) {
    if (rate != null) VoiceService.rate = rate;
    if (pitch != null) VoiceService.pitch = pitch;
    if (volume != null) VoiceService.volume = volume;
  }

  /// Dostępne profile głosów. W wersji produkcyjnej lista jest budowana
  /// dynamicznie z `_tts.getVoices` + lokalnych modeli TTS (wymaganie #4).
  static const List<VoiceProfile> library = [
    VoiceProfile(
      id: 'voice-pl-1',
      name: 'Husarz (PL)',
      languageCode: 'pl-PL',
      description: 'Męski, stanowczy głos narratora.',
      isLocal: true,
    ),
    VoiceProfile(
      id: 'voice-pl-2',
      name: 'Wilczyca (PL)',
      languageCode: 'pl-PL',
      description: 'Żeński, wyrazisty głos.',
      isLocal: true,
    ),
    VoiceProfile(
      id: 'voice-en-1',
      name: 'The Wolf (EN)',
      languageCode: 'en-US',
      description: 'Głęboki angielski głos.',
      isLocal: true,
    ),
  ];

  /// Odsłuch próbki wybranego głosu (wymaganie #3).
  Future<void> preview(String voiceId) async {
    final v = library.firstWhere((e) => e.id == voiceId);
    await _tts.setLanguage(v.languageCode);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    await _tts.speak('Czarne Wilki Prawdy. Wszyscy won!');
  }

  /// Czytanie tekstu wybranym głosem.
  Future<void> speak(String voiceId, String text) async {
    final v = library.firstWhere((e) => e.id == voiceId);
    await _tts.setLanguage(v.languageCode);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
