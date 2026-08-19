import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/telegram/telegram_service.dart';

/// Konfiguracja zdalnego dostępu przez Telegram (Bot API).
class TelegramScreen extends StatefulWidget {
  const TelegramScreen({super.key});

  @override
  State<TelegramScreen> createState() => _TelegramScreenState();
}

class _TelegramScreenState extends State<TelegramScreen> {
  late final TextEditingController _token;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(
        text: context.read<TelegramService>().token);
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tg = context.watch<TelegramService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Telegram (zdalny dostęp)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Zdobądź token bota od @BotFather i wklej go poniżej. '
            'Aplikacja będzie odbierać polecenia w tle.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            style: const TextStyle(color: AppColors.white),
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Token bota',
              hintText: '123456789:AA...',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Włącz integrację',
                style: TextStyle(color: AppColors.white)),
            subtitle: Text(
              tg.connected ? 'Połączono (nasłuch aktywny)' : 'Nasłuch wyłączony',
              style: const TextStyle(color: Colors.grey),
            ),
            value: tg.enabled,
            activeColor: AppColors.red,
            onChanged: (v) => tg.setEnabled(v),
          ),
          if (tg.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('⚠ ${tg.lastError}',
                  style: const TextStyle(color: Colors.orange)),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.save, color: AppColors.white),
            label: const Text('Zapisz token'),
            onPressed: () async {
              await tg.setToken(_token.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Zapisano token bota')),
              );
            },
          ),
        ],
      ),
    );
  }
}
