import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Nasłuch mikrofonu z ręcznym sterowaniem.
///
/// Zasada działania: po uaktywnieniu nasłuch trwa NEPRZERWANIE —
/// metoda [stop] wywoływana jest WYŁĄCZNIE przez przycisk „Stop”
/// użytkownika. Silnik rozpoznawania Androida kończy sesje po kilku
/// sekundach ciszy, dlatego usługa automatowo restartuje nasłuch
/// (pętla [\_keepListening]) tak długo, aż użytkownik sam zatrzyma.
class SttService {
  final SpeechToText _stt = SpeechToText();

  final _statusCtrl = StreamController<bool>.broadcast();
  final _wordsCtrl = StreamController<String>.broadcast();

  /// Strumień stanu: true = trwa nasłuch.
  Stream<bool> get onListening => _statusCtrl.stream;

  /// Strumień rozpoznanych słów (częściowe i końcowe).
  Stream<String> get onWords => _wordsCtrl.stream;

  bool _enabled = false;
  bool _userRequestedStop = false;
  String _accumulated = '';

  bool get isAvailable => _enabled;
  bool get isListening => _stt.isListening;

  /// Uruchom ciągły nasłuch. Wywołaj [stop], aby zakończyć — nic innego
  /// nie przerywa pętli.
  Future<bool> start() async {
    if (!_enabled) {
      _enabled = await _stt.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      if (!_enabled) return false;
    }
    _userRequestedStop = false;
    _accumulated = '';
    await _listenSession();
    return true;
  }

  Future<void> _listenSession() async {
    if (_userRequestedStop) return;
    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
    _statusCtrl.add(true);
  }

  void _onStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      if (!_userRequestedStop) {
        // AUTOZATRZYMANIE WYŁĄCZONE: natychmiast restartujemy sesję.
        Timer(const Duration(milliseconds: 120), _listenSession);
      } else {
        _statusCtrl.add(false);
      }
    }
  }

  void _onError(Object error) {
    if (!_userRequestedStop) {
      Timer(const Duration(milliseconds: 400), _listenSession);
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      _accumulated += result.recognizedWords;
      _wordsCtrl.add(_accumulated);
    } else {
      _wordsCtrl.add('$_accumulated${result.recognizedWords}');
    }
  }

  /// JEDYNE miejsce zakończenia nasłuchu — przycisk „Stop” użytkownika.
  Future<void> stop() async {
    _userRequestedStop = true;
    await _stt.stop();
    _statusCtrl.add(false);
  }

  void dispose() {
    _userRequestedStop = true;
    _statusCtrl.close();
    _wordsCtrl.close();
  }
}
