import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import '../../core/constants.dart';
import '../../services/comments/comments_service.dart';
import '../../services/settings/app_settings.dart';
import '../../services/support/support_service.dart';
import '../../services/voice_service.dart';
import '../../state/app_state.dart';

/// Ustawienia każdego modułu (sekcja per wymaganie).
///
/// Pola z własnym serwisem (tryb online, model, klucz API, głos, agent,
/// Telegram, komentarze) są edytowane w dedykowanych ekranach; reszta
/// konfiguracji żyje w `AppSettings` i jest edytowana tutaj.
class ModuleSettingsScreen extends StatelessWidget {
  const ModuleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia modułów')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _section('#1 · Synchronizacja międzyplatformowa'),
          SwitchListTile(
            title: const Text('Włącz synchronizację',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Most Android ↔ desktop',
                style: TextStyle(color: Colors.grey)),
            value: s.get<bool>('syncEnabled'),
            activeColor: AppColors.red,
            onChanged: (v) => s.setBool('syncEnabled', v),
          ),
          _field(s, 'syncRelay', 'Adres relay (WebRTC/serwer sygnalizacji)', Icons.link),

          _section('#2 · Mikrofon / rozpoznawanie mowy'),
          _field(s, 'sttLocale', 'Język STT (np. pl-PL)', Icons.language),

          _section('#3 · Głosy AI (TTS)'),
          _slider(s, 'ttsRate', 'Szybkość mowy', 0.0, 1.0),
          _slider(s, 'ttsPitch', 'Wysokość głosu', 0.5, 2.0),
          _slider(s, 'ttsVolume', 'Głośność', 0.0, 1.0),

          _section('#4 / #19 · Modele lokalne (llama.cpp)'),
          _intField(s, 'contextSize', 'Rozmiar kontekstu (tokeny)', Icons.memory),
          _intField(s, 'gpuLayers', 'Warstwy GPU (-1 = auto)', Icons.graphic_eq),

          _section('#5 · Tryb sieciowy / offline'),
          _linkTile(context, 'Tryb online/offline + dostawca AI', AppRouter.settings),

          _section('#8 · Agent automatyzacji'),
          _intField(s, 'agentMaxSteps', 'Maks. liczba kroków', Icons.repeat),
          _intField(s, 'agentStepDelayMs', 'Opóźnienie między krokami (ms)', Icons.timer),

          _section('#9 · Personalizacja agenta'),
          _linkTile(context, 'Nazwa, rola, System Prompt', AppRouter.agent),

          _section('#10 · Asystent kodowania'),
          _field(s, 'coderLanguage', 'Domyślny język', Icons.code),

          _section('#11 · Samonaprawa / iniekcja kodu'),
          _field(s, 'dexPath', 'Ścieżka pliku .dex', Icons.file_upload),

          _section('#12 · Komunikator E2E'),
          _field(s, 'messengerRelay', 'Adres relay WebSocket', Icons.lock),

          _section('#13 · Radio społecznościowe'),
          _field(s, 'radioRelay', 'Adres sygnalizacji radio', Icons.radio),

          _section('#14 · Historia konwersacji (SQLite)'),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: AppColors.red),
            title: const Text('Wyczyść historię',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Usuwa lokalną historię rozmów',
                style: TextStyle(color: Colors.grey)),
            onTap: () async {
              await context.read<AppState>().clearHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Historia wyczyszczona')),
              );
            },
          ),

          _section('#15 · RBAC (role i uprawnienia)'),
          _linkTile(context, 'Użytkownicy i role', AppRouter.admin),

          _section('#16 · Moderacja treści'),
          SwitchListTile(
            title: const Text('Automatyczne zatwierdzanie',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text(
                'OFF = kontroler jakości zatwierdza ręcznie (#22)',
                style: TextStyle(color: Colors.grey)),
            value: s.get<bool>('moderationAutoApprove'),
            activeColor: AppColors.red,
            onChanged: (v) => s.setBool('moderationAutoApprove', v),
          ),

          _section('#17 · Ogłoszenia i alerty'),
          SwitchListTile(
            title: const Text('Alerty priorytetowe',
                style: TextStyle(color: AppColors.white)),
            value: s.get<bool>('alertsEnabled'),
            activeColor: AppColors.red,
            onChanged: (v) => s.setBool('alertsEnabled', v),
          ),
          SwitchListTile(
            title: const Text('Ogłoszenia',
                style: TextStyle(color: AppColors.white)),
            value: s.get<bool>('announcementsEnabled'),
            activeColor: AppColors.red,
            onChanged: (v) => s.setBool('announcementsEnabled', v),
          ),

          _section('#18 · Agent w komentarzach'),
          _commentsToggle(),

          _section('#21 · Wsparcie / wpłaty'),
          _supportSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4, left: 4),
        child: Text(title,
            style: const TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  Widget _field(AppSettings s, String key, String label, IconData icon) {
    final ctl = TextEditingController(text: s.get<String>(key));
    return ListTile(
      leading: Icon(icon, color: AppColors.white),
      title: TextField(
        controller: ctl,
        style: const TextStyle(color: AppColors.white),
        decoration: InputDecoration(labelText: label, isDense: true),
        onSubmitted: (v) => s.setString(key, v.trim()),
      ),
    );
  }

  Widget _intField(AppSettings s, String key, String label, IconData icon) {
    final ctl = TextEditingController(text: s.get<int>(key).toString());
    return ListTile(
      leading: Icon(icon, color: AppColors.white),
      title: TextField(
        controller: ctl,
        style: const TextStyle(color: AppColors.white),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
        onSubmitted: (v) {
          final n = int.tryParse(v.trim());
          if (n != null) s.setInt(key, n);
        },
      ),
    );
  }

  Widget _slider(
      AppSettings s, String key, String label, double min, double max) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(color: AppColors.white))),
          Expanded(
            child: Slider(
              value: s.get<double>(key).clamp(min, max),
              min: min,
              max: max,
              activeColor: AppColors.red,
              onChanged: (v) => s.setDouble(key, v),
              onChangeEnd: (v) {
                // Synchronizuj TTS z AppSettings.
                VoiceService.configure(
                  rate: key == 'ttsRate' ? v : null,
                  pitch: key == 'ttsPitch' ? v : null,
                  volume: key == 'ttsVolume' ? v : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(BuildContext context, String label, String route) => ListTile(
        leading: const Icon(Icons.chevron_right, color: AppColors.white),
        title: Text(label, style: const TextStyle(color: AppColors.white)),
        onTap: () => Navigator.pushNamed(context, route),
      );

  Widget _commentsToggle() {
    return Consumer<CommentsService>(
      builder: (_, svc, __) => SwitchListTile(
        title: const Text('Auto-odpowiedzi agenta',
            style: TextStyle(color: AppColors.white)),
        subtitle: const Text('Odpowiada na komentarze po publikacji',
            style: TextStyle(color: Colors.grey)),
        value: svc.autoReply,
        activeColor: AppColors.red,
        onChanged: (v) => svc.setAutoReply(v),
      ),
    );
  }

  Widget _supportSection() {
    return Consumer<SupportService>(
      builder: (_, svc, __) => Column(
        children: [
          for (final m in svc.methods)
            _supportField(svc, m.id, m.name, m.destination),
        ],
      ),
    );
  }

  Widget _supportField(
      SupportService svc, String id, String label, String value) {
    final ctl = TextEditingController(text: value);
    return ListTile(
      leading: const Icon(Icons.account_balance_wallet, color: AppColors.white),
      title: TextField(
        controller: ctl,
        style: const TextStyle(color: AppColors.white),
        decoration: InputDecoration(labelText: label, isDense: true),
        onSubmitted: (v) => svc.updateMethod(id, v),
      ),
    );
  }
}
