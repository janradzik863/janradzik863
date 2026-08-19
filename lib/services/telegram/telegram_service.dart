import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Polecenie odebrane z Telegrama.
class TelegramCommand {
  final int updateId;
  final int chatId;
  final String text;
  final String? senderName;
  final DateTime receivedAt;

  TelegramCommand({
    required this.updateId,
    required this.chatId,
    required this.text,
    this.senderName,
    required this.receivedAt,
  });
}

/// Integracja z Telegram Bot API (zdalny dostęp agenta).
///
/// Ankieta w tle (long-polling `getUpdates`) umożliwia wydawanie poleceń
/// i monitorowanie postępu zdalnie. W wersji produkcyjnej polling jest
/// przeniesiony do foreground service / WorkManager, by działał po zamknięciu
/// aplikacji; tu działa w trakcie życia aplikacji.
class TelegramService extends ChangeNotifier {
  String _token = '';
  bool _enabled = false;
  bool _connected = false;
  String? _lastError;

  int _offset = 0;
  Timer? _poller;

  String get token => _token;
  bool get enabled => _enabled;
  bool get connected => _connected;
  String? get lastError => _lastError;

  /// Wywoływane przy każdej nowej wiadomości (używa go AgentController).
  void Function(TelegramCommand command)? onCommand;

  static const _prefToken = 'telegram.token';
  static const _prefEnabled = 'telegram.enabled';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_prefToken) ?? '';
    _enabled = prefs.getBool(_prefEnabled) ?? false;
    if (_enabled && _token.isNotEmpty) {
      start();
    }
    notifyListeners();
  }

  Future<void> setToken(String token) async {
    _token = token.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefToken, _token);
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, v);
    if (v && _token.isNotEmpty) {
      start();
    } else {
      stop();
    }
    notifyListeners();
  }

  static const MethodChannel _fg =
      MethodChannel('czarne_wilki/telegram_fg');

  void start() {
    if (_poller != null) return;
    _connected = true;
    _lastError = null;
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _poll(); // natychmiastowy pierwszy odczyt
    _startForegroundService();
    notifyListeners();
  }

  void stop() {
    _poller?.cancel();
    _poller = null;
    _connected = false;
    _stopForegroundService();
    notifyListeners();
  }

  /// Utrzymuje proces przy życiu w tle (foreground service na Androidzie).
  Future<void> _startForegroundService() async {
    try {
      await _fg.invokeMethod('start');
    } on MissingPluginException {
      // desktop — brak usługi pierwszoplanowej
    } catch (_) {
      // ignoruj — polling działa też w trakcie życia aplikacji
    }
  }

  Future<void> _stopForegroundService() async {
    try {
      await _fg.invokeMethod('stop');
    } catch (_) {
      // ignoruj
    }
  }

  Future<void> _poll() async {
    if (_token.isEmpty) return;
    try {
      final uri = Uri.parse(
          'https://api.telegram.org/bot$_token/getUpdates'
          '?timeout=1&offset=$_offset');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        _lastError = 'Telegram: HTTP ${resp.statusCode}';
        _connected = false;
        notifyListeners();
        return;
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['ok'] != true) {
        _lastError = 'Telegram: ${data['description']}';
        _connected = false;
        notifyListeners();
        return;
      }
      _connected = true;
      final updates = data['result'] as List? ?? [];
      for (final u in updates) {
        final update = u as Map<String, dynamic>;
        final id = update['update_id'] as int? ?? 0;
        _offset = id + 1;
        final message = update['message'] as Map<String, dynamic>?;
        if (message == null) continue;
        final text = message['text'] as String?;
        if (text == null || text.isEmpty) continue;
        final chat = message['chat'] as Map<String, dynamic>?;
        final chatId = chat?['id'] as int? ?? 0;
        final from = message['from'] as Map<String, dynamic>?;
        final name = from?['first_name'] as String?;
        onCommand?.call(TelegramCommand(
          updateId: id,
          chatId: chatId,
          text: text,
          senderName: name,
          receivedAt: DateTime.now(),
        ));
      }
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      _connected = false;
      notifyListeners();
    }
  }

  /// Wysyła wiadomość do czatu (monitorowanie postępu zadania).
  Future<bool> sendMessage(int chatId, String text) async {
    if (_token.isEmpty) return false;
    try {
      final uri = Uri.parse(
          'https://api.telegram.org/bot$_token/sendMessage'
          '?chat_id=$chatId&text=${Uri.encodeComponent(text)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
