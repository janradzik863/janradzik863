import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/messenger/messenger_service.dart';

/// Ekran szyfrowanego komunikatora (#12).
class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MessengerService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Komunikator (E2E)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    svc.connected ? Icons.lock : Icons.lock_open,
                    size: 16,
                    color: svc.connected ? AppColors.red : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    svc.connected ? 'szyfrowane' : 'lokalnie',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _IdentityBar(svc: svc),
          const Divider(height: 1, color: AppColors.surface),
          Expanded(
            child: svc.messages.isEmpty
                ? const Center(
                    child: Text('Brak wiadomości',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: svc.messages.length,
                    itemBuilder: (c, i) {
                      final m = svc.messages[i];
                      final mine = m.sender == svc.myPublicKey;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: mine
                                ? AppColors.red
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(m.text,
                              style: const TextStyle(color: AppColors.white)),
                        ),
                      );
                    },
                  ),
          ),
          _InputBar(controller: _input, svc: svc),
        ],
      ),
    );
  }
}

class _IdentityBar extends StatelessWidget {
  final MessengerService svc;
  const _IdentityBar({required this.svc});

  @override
  Widget build(BuildContext context) {
    final key = svc.myPublicKey;
    final short = key.length > 24 ? '${key.substring(0, 12)}…' : key;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.vpn_key, color: AppColors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Twój klucz publiczny (tożsamość)',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                Text(short,
                    style: const TextStyle(
                        color: AppColors.white, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dodaj kontakt',
            icon: const Icon(Icons.person_add, color: AppColors.white),
            onPressed: () => _addContact(context),
          ),
          IconButton(
            tooltip: 'Nowa grupa',
            icon: const Icon(Icons.group_add, color: AppColors.white),
            onPressed: () => _createGroup(context),
          ),
        ],
      ),
    );
  }

  void _addContact(BuildContext context) {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Dodaj kontakt',
            style: TextStyle(color: AppColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctl,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(labelText: 'Klucz publiczny (base64)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () {
              svc.addContact(ctl.text.trim(), 'Kontakt');
              Navigator.pop(ctx);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  void _createGroup(BuildContext context) {
    final nameCtl = TextEditingController();
    final memberCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nowa grupa',
            style: TextStyle(color: AppColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(labelText: 'Nazwa grupy'),
            ),
            TextField(
              controller: memberCtl,
              style: const TextStyle(color: AppColors.white),
              decoration: const InputDecoration(
                  labelText: 'Klucze członków (base64, po przecinku)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () {
              final members = memberCtl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
                ..add(svc.myPublicKey);
              svc.createGroup(nameCtl.text.trim(), members);
              Navigator.pop(ctx);
            },
            child: const Text('Utwórz'),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final MessengerService svc;
  const _InputBar({required this.controller, required this.svc});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.white),
                decoration: const InputDecoration(
                  hintText: 'Zaszyfrowana wiadomość…',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Wyślij (E2E)',
              icon: const Icon(Icons.lock, color: AppColors.red),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                controller.clear();
                // Wysyłka do pierwszego kontaktu (demo) — w produkcji wybór
                // rozmówcy/grupy z listy.
                if (svc.contacts.isNotEmpty) {
                  svc.sendToContact(svc.contacts.values.first, text);
                } else if (svc.groups.isNotEmpty) {
                  svc.sendToGroup(svc.groups.values.first, text);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
