import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto.dart';

/// Pojedyncza wiadomość komunikatora.
class SecureMessage {
  final String sender; // base64 klucza publicznego nadawcy
  final String text;
  final DateTime sentAt;
  final String? groupId;

  SecureMessage({
    required this.sender,
    required this.text,
    required this.sentAt,
    this.groupId,
  });

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'text': text,
        'sentAt': sentAt.millisecondsSinceEpoch,
        'groupId': groupId,
      };

  static SecureMessage fromJson(Map<String, dynamic> m) => SecureMessage(
        sender: m['sender'] as String,
        text: m['text'] as String,
        sentAt: DateTime.fromMillisecondsSinceEpoch(m['sentAt'] as int),
        groupId: m['groupId'] as String?,
      );
}

/// Kontakt (klucz publiczny + nazwa).
class Contact {
  final String pubKey; // base64
  final String name;
  Contact({required this.pubKey, required this.name});
}

/// Grupa (zbiór kluczy publicznych członków).
class Group {
  final String id;
  final String name;
  final List<String> members;
  Group({required this.id, required this.name, required this.members});
}

/// Niezależny, szyfrowany komunikator E2E (wymaganie #12).
///
/// Transport: WebSocket do serwera-przekaźnika (relay) — serwer widzi wyłącznie
/// koperty zaszyfrowane E2E (nie może odczytać treści). Połączenia grupowe
/// realizowane są jako szyfrowanie per-odbiorca (każdy członek dostaje kopertę
/// zaszyfrowaną swoim kluczem). Wariant bez pośrednika (WebRTC DataChannel)
/// współdzieli ten sam kontrakt wiadomości.
class MessengerService extends ChangeNotifier {
  final CryptoEngine crypto = CryptoEngine();

  final Map<String, Contact> _contacts = {}; // pubKey -> Contact
  final Map<String, Group> _groups = {}; // id -> Group
  final List<SecureMessage> _messages = [];

  bool _connected = false;
  WebSocket? _socket;
  StreamSubscription? _sub;

  List<SecureMessage> get messages => List.unmodifiable(_messages);
  Map<String, Contact> get contacts => Map.unmodifiable(_contacts);
  Map<String, Group> get groups => Map.unmodifiable(_groups);
  bool get connected => _connected;
  String get myPublicKey => CryptoEngine.encodePub(crypto.identityPublic);

  static const _prefIdSeed = 'messenger.identitySeed';
  static const _prefContacts = 'messenger.contacts';

  // --- Tożsamość ---

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final seedB64 = prefs.getString(_prefIdSeed);
    if (seedB64 != null) {
      await crypto.loadIdentityFromSeed(base64Decode(seedB64));
    } else {
      await crypto.generateIdentity();
      final seed = crypto.identitySeed;
      if (seed != null) {
        await prefs.setString(_prefIdSeed, base64Encode(seed));
      }
    }
    final contactsB64 = prefs.getString(_prefContacts);
    if (contactsB64 != null) {
      final list = jsonDecode(contactsB64) as List;
      for (final e in list) {
        final c = Contact(pubKey: e['pubKey'] as String, name: e['name'] as String);
        _contacts[c.pubKey] = c;
      }
    }
    notifyListeners();
  }

  // --- Kontakty i grupy ---

  Future<void> addContact(String pubKeyB64, String name) async {
    _contacts[pubKeyB64] = Contact(pubKey: pubKeyB64, name: name);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> createGroup(String name, List<String> memberPubKeys) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final g = Group(id: id, name: name, members: memberPubKeys);
    _groups[id] = g;
    notifyListeners();
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _contacts.values
        .map((c) => {'pubKey': c.pubKey, 'name': c.name})
        .toList();
    await prefs.setString(_prefContacts, jsonEncode(list));
  }

  // --- Transport (relay) ---

  Future<void> connect(String relayUrl) async {
    try {
      _socket = await WebSocket.connect(relayUrl);
      _connected = true;
      _sub = _socket!.listen(_onRaw, onDone: () {
        _connected = false;
        notifyListeners();
      });
    } catch (_) {
      _connected = false;
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _socket?.close();
    _socket = null;
    _connected = false;
    notifyListeners();
  }

  void _onRaw(dynamic data) {
    _handleRaw(data);
  }

  Future<void> _handleRaw(dynamic data) async {
    try {
      final envelope = base64Decode(data as String);
      final clear = await crypto.decryptMessage(envelope);
      final msg = SecureMessage.fromJson(
          jsonDecode(utf8.decode(clear)) as Map<String, dynamic>);
      _messages.add(msg);
      notifyListeners();
    } catch (_) {
      // Nie można odszyfrować — nie nasza wiadomość lub uszkodzona koperta.
    }
  }

  /// Wysyła zaszyfrowaną wiadomość do konkretnego odbiorcy.
  Future<void> sendToContact(Contact c, String text) async {
    final msg = SecureMessage(
      sender: myPublicKey,
      text: text,
      sentAt: DateTime.now(),
    );
    final clear = utf8.encode(jsonEncode(msg.toJson()));
    final envelope =
        await crypto.encryptMessage(clear, CryptoEngine.decodePub(c.pubKey));
    _messages.add(msg);
    _sendEnvelope(base64Encode(envelope));
    notifyListeners();
  }

  /// Wysyła do wszystkich członków grupy (szyfrowanie per-odbiorca).
  Future<void> sendToGroup(Group g, String text) async {
    final msg = SecureMessage(
      sender: myPublicKey,
      text: text,
      sentAt: DateTime.now(),
      groupId: g.id,
    );
    final clear = utf8.encode(jsonEncode(msg.toJson()));
    for (final member in g.members) {
      final envelope =
          await crypto.encryptMessage(clear, CryptoEngine.decodePub(member));
      _sendEnvelope(base64Encode(envelope));
    }
    _messages.add(msg);
    notifyListeners();
  }

  void _sendEnvelope(String b64) {
    // Po sieci idą wyłącznie koperty zaszyfrowane E2E.
    _socket?.add(b64);
  }
}
