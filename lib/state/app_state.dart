import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../services/audio/mic_service.dart';
import '../services/llm_service.dart';

/// Główny stan aplikacji (ChangeNotifier / Provider).
///
/// Odpowiada za: tryb online/offline (#5), konfigurację agenta (#9),
/// aktywny głos (#3), sterowanie mikrofonem (#2) oraz historię (#14).
class AppState extends ChangeNotifier {
  final AppDatabase _db;
  final MicService _mic = MicService();

  AppState(this._db);

  // --- Tryb sieciowy / offline (#5) ---
  bool _onlineMode = false;
  bool get onlineMode => _onlineMode;

  // --- Konfiguracja agenta (#9) ---
  AgentConfig _agent = const AgentConfig();
  AgentConfig get agent => _agent;

  // --- Aktywny głos (#3) ---
  String _voiceId = 'voice-pl-1';
  String get voiceId => _voiceId;

  // --- Dostawca AI: klucz API / Base URL (#4, #5) ---
  String _apiKey = '';
  String get apiKey => _apiKey;
  String _baseUrl = 'https://openrouter.ai/api/v1';
  String get baseUrl => _baseUrl;

  // --- Sterowanie mikrofonem (#2) ---
  bool _recording = false;
  bool get recording => _recording;

  // --- Modele i historia (#4, #14) ---
  List<String> _availableModels = [
    'openai/gpt-oss-120b:free',
    'deepseek-chat',
    'deepseek-reasoner',
    'llama3-8b (lokalny GGUF)',
    'qwen2-vl (lokalny, wizja)',
  ];
  List<String> get availableModels => _availableModels;

  String _activeModel = 'openai/gpt-oss-120b:free';
  String get activeModel => _activeModel;

  final List<Message> _messages = [];
  List<Message> get messages => List.unmodifiable(_messages);

  int? _conversationId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _onlineMode = prefs.getBool('onlineMode') ?? false;
    _voiceId = prefs.getString('voiceId') ?? 'voice-pl-1';
    _activeModel = prefs.getString('activeModel') ??
        'openai/gpt-oss-120b:free';
    _apiKey = prefs.getString('apiKey') ?? '';
    _baseUrl = prefs.getString('baseUrl') ?? 'https://openrouter.ai/api/v1';
    LlmService.configure(apiKey: _apiKey, baseUrl: _baseUrl);
    final name = prefs.getString('agentName');
    final role = prefs.getString('agentRole');
    final sys = prefs.getString('agentPrompt');
    if (name != null || role != null || sys != null) {
      _agent = AgentConfig(
        name: name ?? _agent.name,
        role: role ?? _agent.role,
        systemPrompt: sys ?? _agent.systemPrompt,
      );
    }
    await _ensureConversation();
    notifyListeners();
  }

  Future<void> _ensureConversation() async {
    if (_conversationId != null) return;
    final convs = await _db.conversations();
    if (convs.isEmpty) {
      _conversationId = await _db.createConversation('Nowa rozmowa', _activeModel);
    } else {
      _conversationId = convs.first.id;
      final msgs = await _db.messagesFor(_conversationId!);
      _messages
        ..clear()
        ..addAll(msgs);
    }
  }

  // --- Settery z trwałością ---

  Future<void> setOnlineMode(bool v) async {
    _onlineMode = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onlineMode', v);
    notifyListeners();
  }

  Future<void> setVoice(String id) async {
    _voiceId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voiceId', id);
    notifyListeners();
  }

  Future<void> setActiveModel(String model) async {
    _activeModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeModel', model);
    notifyListeners();
  }

  Future<void> setAgent(AgentConfig cfg) async {
    _agent = cfg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agentName', cfg.name);
    await prefs.setString('agentRole', cfg.role);
    await prefs.setString('agentPrompt', cfg.systemPrompt);
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    LlmService.configure(apiKey: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', key);
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    LlmService.configure(baseUrl: url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', url);
    notifyListeners();
  }

  // --- Mikrofon (#2) ---

  /// Ręczne sterowanie: nasłuch trwa aż do jawnego Stop.
  /// Brak autozatrzymywania (wymaganie #2). Używa natywnego AudioRecord.
  Future<void> startListening() async {
    if (_recording) return;
    final ok = await _mic.start();
    _recording = ok;
    notifyListeners();
  }

  Future<void> stopListening() async {
    if (!_recording) return;
    await _mic.stop();
    _recording = false;
    notifyListeners();
  }

  // --- Wiadomości ---

  Future<void> sendMessage(String text) async {
    final id = await _ensureConversationId();
    final m = Message(
      conversationId: id,
      role: MessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );
    _messages.add(m);
    await _db.insertMessage(m);
    notifyListeners();
    // Odpowiedź modelu obsługiwana przez LlmService (wymaganie #4/#5/#19).
  }

  Future<int> _ensureConversationId() async {
    if (_conversationId == null) await _ensureConversation();
    return _conversationId!;
  }

  /// Czyści lokalną historię konwersacji (#14).
  Future<void> clearHistory() async {
    final id = await _ensureConversationId();
    await _db.clearMessages(id);
    _messages.clear();
    notifyListeners();
  }
}
