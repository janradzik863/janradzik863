import 'dart:async';

import 'package:flutter/foundation.dart';

import '../automation/accessibility_bridge.dart';
import '../automation/task_agent.dart';
import '../data/app_database.dart';
import '../data/models.dart';
import '../engine/ai_engine.dart';
import '../engine/engine_manager.dart';
import '../engine/image_engine.dart';
import '../voice/stt_service.dart';
import '../voice/tts_service.dart';

/// Profil agenta (personalizacja): imię, rola, instrukcja systemowa.
class AgentProfileController extends ChangeNotifier {
  AgentProfileController({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;

  AgentProfile _profile = AgentProfile(
    name: 'Wilk',
    role: 'Wierny asystent właściciela urządzenia',
    systemPrompt:
        'Jesteś prywatnym asystentem AI działającym w aplikacji Czarne Wilki. '
        'Odpowiadasz rzeczowo, po polsku, w tonie godnym i konkretnym. '
        'Wszystkie rozmowy mają miejsce na urządzeniu użytkownika.',
  );

  AgentProfile get profile => _profile;

  Future<void> load() async {
    final name = await _db.getSetting('agent_name');
    final role = await _db.getSetting('agent_role');
    final sys = await _db.getSetting('agent_system_prompt');
    final temp = double.tryParse(await _db.getSetting('agent_temp') ?? '');
    if (name != null || role != null || sys != null) {
      _profile = _profile.copyWith(
        name: name,
        role: role,
        systemPrompt: sys,
        temperature: temp,
      );
      notifyListeners();
    }
  }

  Future<void> save(AgentProfile p) async {
    _profile = p;
    await _db.setSetting('agent_name', p.name);
    await _db.setSetting('agent_role', p.role);
    await _db.setSetting('agent_system_prompt', p.systemPrompt);
    await _db.setSetting('agent_temp', p.temperature.toString());
    notifyListeners();
  }
}

/// Kontroler czatu: rozmowa, historia w SQLite, streaming odpowiedzi,
/// generowanie obrazów i odczyt głosowy.
class ChatController extends ChangeNotifier {
  ChatController({
    required this.engines,
    required this.profile,
    required this.voice,
    AppDatabase? db,
    ImageEngine? imageEngine,
  })  : _db = db ?? AppDatabase(),
        _imageEngine = imageEngine ?? ImageEngine();

  final EngineManager engines;
  final AgentProfileController profile;
  final VoiceController voice;
  final AppDatabase _db;
  final ImageEngine _imageEngine;

  final SttService stt = SttService();

  Conversation? _conversation;
  List<Message> _messages = [];
  String _partial = '';
  bool _busy = false;
  String? _error;
  StreamSubscription? _sttWords;

  Conversation? get conversation => _conversation;
  List<Message> get messages => _messages;
  String get partial => _partial;
  bool get busy => _busy;
  String? get error => _error;
  bool get micActive => stt.isListening;

  /// Rozpoznane słowa z mikrofonu (do pola wprowadzania).
  final micWordsCtrl = StreamController<String>.broadcast();
  Stream<String> get micWords => micWordsCtrl.stream;

  Future<void> openConversation() async {
    if (_conversation != null) return;
    final list = await _db.listConversations();
    if (list.isEmpty) {
      _conversation = await _db.createConversation('Rozmowa');
    } else {
      _conversation = list.first;
    }
    await _reload();
  }

  Future<void> newConversation() async {
    _conversation = await _db.createConversation('Rozmowa');
    _messages = [];
    notifyListeners();
  }

  /// Odświeża stan z bazy (np. po imporcie kopii zapasowej).
  Future<void> reloadFromDb() async {
    _conversation = null;
    await openConversation();
  }

  Future<void> _reload() async {
    if (_conversation == null) return;
    _messages = await _db.messagesFor(_conversation!.id);
    notifyListeners();
  }

  /// Wysłanie wiadomości tekstowej do aktywnego silnika.
  Future<void> send(String text) async {
    final engine = engines.engine;
    if (engine == null) {
      _error = engines.online
          ? 'Brak aktywnego modelu — wybierz model w ekranie Modeli.'
          : 'Tryb Offline bez aktywnego modelu lokalnego. Pobierz model GGUF '
              'lub włącz tryb Sieciowy.';
      notifyListeners();
      return;
    }

    await openConversation();
    final conv = _conversation!;
    await _db.addMessage(Message(
      id: 0,
      conversationId: conv.id,
      role: Role.user,
      content: text,
      createdAt: DateTime.now(),
    ));
    await _reload();

    _busy = true;
    _error = null;
    _partial = '';
    notifyListeners();

    final history = [
      for (final m in _messages.take(_messages.length - 1))
        (m.role.name, m.content),
    ];

    try {
      await engine.ensureReady();
      final buffer = StringBuffer();
      await for (final chunk in engine.chat(
        system: profile.profile.effectiveSystemPrompt,
        turns: [...history, ('user', text)],
        temperature: profile.profile.temperature,
      )) {
        buffer.write(chunk);
        _partial = buffer.toString();
        notifyListeners();
      }
      await _db.addMessage(Message(
        id: 0,
        conversationId: conv.id,
        role: Role.assistant,
        content: buffer.toString(),
        createdAt: DateTime.now(),
        modelName: engine.displayName,
      ));
    } on AiEngineException catch (e) {
      _error = e.userHint ?? e.message;
    } catch (e) {
      _error = 'Błąd silnika: $e';
    } finally {
      _partial = '';
      _busy = false;
      await _reload();
    }
  }

  /// Generowanie obrazu (tylko tryb Sieciowy — usługa zewnętrzna).
  Future<void> generateImage(String prompt) async {
    if (!engines.online) {
      _error = 'Generowanie obrazów wymaga trybu Sieciowego '
          '(usługa zewnętrzna). Offline = zero połączeń.';
      notifyListeners();
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      final path = await _imageEngine.generate(prompt: prompt);
      await openConversation();
      await _db.addMessage(Message(
        id: 0,
        conversationId: _conversation!.id,
        role: Role.user,
        content: prompt,
        createdAt: DateTime.now(),
      ));
      await _db.addMessage(Message(
        id: 0,
        conversationId: _conversation!.id,
        role: Role.assistant,
        content: 'Wygenerowano obraz.',
        createdAt: DateTime.now(),
        attachmentPath: path,
      ));
      await _reload();
    } catch (e) {
      _error = 'Nie udało się wygenerować obrazu: $e';
      notifyListeners();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Odczyt ostatniej odpowiedzi głosu agenta.
  Future<void> speakLast() async {
    final last = _messages.lastWhereOrNull((m) => m.role == Role.assistant);
    if (last != null) await voice.speak(last.content);
  }

  // ------------------------------------------------------------ mikrofon

  Future<void> startMic() async {
    _sttWords ??= stt.onWords.listen(micWordsCtrl.add);
    await stt.start();
    notifyListeners();
  }

  /// Wyłącznie ręczne zatrzymanie (przycisk Stop).
  Future<void> stopMic() async {
    await stt.stop();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sttWords?.cancel();
    stt.dispose();
    micWordsCtrl.close();
    super.dispose();
  }
}

extension _LastWhereOrNull<T> on Iterable<T> {
  T? lastWhereOrNull(bool Function(T) test) {
    T? found;
    for (final e in this) {
      if (test(e)) found = e;
    }
    return found;
  }
}

/// Kontroler głosów (biblioteka TTS). Na platformach bez wsparcia TTS
/// (np. Linux) lista głosów pozostaje pusta, a UI pokazuje stosowny komunikat.
class VoiceController extends ChangeNotifier {
  VoiceController({TtsService? tts}) : _tts = tts ?? TtsService();

  final TtsService _tts;
  bool _ttsAvailable = true;

  bool get ttsAvailable => _ttsAvailable;

  List<TtsVoice> get voices => _tts.voicesPolishFirst;
  String? get activeVoice => _tts.activeVoice;
  double get rate => _tts.rate;
  double get pitch => _tts.pitch;
  bool get speaking => _tts.speaking;

  Future<void> init() async {
    try {
      await _tts.init();
    } catch (_) {
      _ttsAvailable = false;
    }
    notifyListeners();
  }

  Future<void> preview(TtsVoice v) async {
    if (!_ttsAvailable) return;
    await _tts.preview(v);
    notifyListeners();
  }

  Future<void> select(TtsVoice v) async {
    if (!_ttsAvailable) return;
    await _tts.select(v);
    notifyListeners();
  }

  Future<void> setRate(double v) async {
    if (!_ttsAvailable) return;
    await _tts.setRate(v);
    notifyListeners();
  }

  Future<void> setPitch(double v) async {
    if (!_ttsAvailable) return;
    await _tts.setPitch(v);
    notifyListeners();
  }

  Future<void> speak(String text) async {
    if (!_ttsAvailable) return;
    await _tts.speak(text);
    notifyListeners();
  }

  Future<void> stopSpeaking() async {
    if (!_ttsAvailable) return;
    await _tts.stop();
    notifyListeners();
  }
}

/// Kontroler automatyzacji urządzenia.
class AutomationController extends ChangeNotifier {
  AutomationController({required this.engines})
      : agent = TaskAgent(engineGetter: () => engines.engine);

  final EngineManager engines;
  final TaskAgent agent;
  final AccessibilityBridge bridge = AccessibilityBridge();

  bool serviceConnected = false;
  AgentState agentState = AgentState.idle;
  final List<AgentLogEntry> log = [];

  StreamSubscription? _logSub;
  StreamSubscription? _stateSub;

  void start() {
    _logSub ??= agent.onLog.listen((e) {
      log.add(e);
      notifyListeners();
    });
    _stateSub ??= agent.onState.listen((s) {
      agentState = s;
      notifyListeners();
    });
  }

  Future<void> refreshConnection() async {
    serviceConnected = await bridge.isConnected();
    notifyListeners();
  }

  Future<void> openSettings() async => bridge.openAccessibilitySettings();

  Future<void> run(String goal) async {
    log.clear();
    notifyListeners();
    await agent.run(goal);
  }

  void stop() => agent.cancel();

  @override
  void dispose() {
    _logSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }
}
