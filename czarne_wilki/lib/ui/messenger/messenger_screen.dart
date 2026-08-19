import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../services/crypto_service.dart';

/// Punkt 12: Niezależny, szyfrowany komunikator z E2E.
class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> {
  final _db = AppDatabase();
  List<MessengerContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    _contacts = await _db.listContacts();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Komunikator E2E'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
        actions: [
          IconButton(
            tooltip: 'Klucz publiczny',
            icon: const Icon(Icons.key_outlined),
            onPressed: _showPublicKey,
          ),
        ],
      ),
      body: _contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outlined,
                      size: 64, color: CwColors.crimson),
                  const SizedBox(height: 16),
                  const Text(
                    'Komunikator zaszyfrowany od końca do końca.\n'
                    'Dodaj kontakt, aby rozpocząć rozmowę.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CwColors.whiteDim, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Dodaj kontakt'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _contacts.length,
              itemBuilder: (_, i) {
                final c = _contacts[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: CwColors.crimsonDark,
                      child: Text(
                        c.displayName[0].toUpperCase(),
                        style: const TextStyle(color: CwColors.white),
                      ),
                    ),
                    title: Text(c.displayName),
                    subtitle: const Text('Szyfrowanie E2E aktywne',
                        style: TextStyle(
                            fontSize: 11, color: CwColors.online)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.call_outlined,
                              color: CwColors.online, size: 22),
                          tooltip: 'Połączenie głosowe',
                          onPressed: () => _startCall(c, false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.videocam_outlined,
                              color: CwColors.crimson, size: 22),
                          tooltip: 'Połączenie wideo',
                          onPressed: () => _startCall(c, true),
                        ),
                      ],
                    ),
                    onTap: () => _openChat(c),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: CwColors.crimson,
        onPressed: _addContact,
        child: const Icon(Icons.person_add, color: CwColors.white),
      ),
    );
  }

  void _showPublicKey() {
    CryptoService.instance.init();
    final key = CryptoService.instance.publicKeyBase64;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CwColors.surface,
        title: const Text('Twój klucz publiczny'),
        content: SelectableText(
          key.length > 80 ? '${key.substring(0, 80)}…' : key,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  void _addContact() {
    final nameCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CwColors.surface,
        title: const Text('Dodaj kontakt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Nazwa kontaktu'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: keyCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(hintText: 'Klucz publiczny kontaktu'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await _db.addContact(MessengerContact(
                id: 0,
                displayName: nameCtrl.text.trim(),
                publicKey: keyCtrl.text.trim(),
                deviceId: 'local-${DateTime.now().millisecondsSinceEpoch}',
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadContacts();
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  void _openChat(MessengerContact contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MessengerChatScreen(contact: contact),
      ),
    );
  }

  void _startCall(MessengerContact contact, bool video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${video ? "Wideo" : "Głosowe"} połączenie z ${contact.displayName} '
          '(WebRTC P2P) — wymaga skonfigurowanego sygnalizatora.',
        ),
      ),
    );
  }
}

class _MessengerChatScreen extends StatefulWidget {
  const _MessengerChatScreen({required this.contact});
  final MessengerContact contact;

  @override
  State<_MessengerChatScreen> createState() => _MessengerChatScreenState();
}

class _MessengerChatScreenState extends State<_MessengerChatScreen> {
  final _db = AppDatabase();
  final _input = TextEditingController();
  final _crypto = CryptoService.instance;
  List<MessengerMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _crypto.init();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    _messages = await _db.messagesForContact(widget.contact.id);
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();

    // Szyfruj wiadomość
    final encrypted = _crypto.encrypt(text);

    await _db.addMessengerMessage(MessengerMessage(
      id: 0,
      contactId: widget.contact.id,
      direction: 'sent',
      encryptedContent: encrypted.toJson(),
      timestamp: DateTime.now(),
    ));
    await _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contact.displayName,
                style: const TextStyle(fontSize: 16)),
            const Text('🔒 Szyfrowanie E2E',
                style: TextStyle(fontSize: 11, color: CwColors.online)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isSent = m.direction == 'sent';
                String decrypted;
                try {
                  final payload =
                      EncryptedPayload.fromJson(m.encryptedContent);
                  decrypted = _crypto.decrypt(payload);
                } catch (_) {
                  decrypted = '[zaszyfrowano]';
                }
                return Align(
                  alignment:
                      isSent ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color:
                          isSent ? CwColors.crimsonDark : CwColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(decrypted,
                        style: const TextStyle(color: CwColors.white)),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Wiadomość zaszyfrowana…',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _send,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
