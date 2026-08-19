import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import '../../core/constants.dart';
import '../../state/app_state.dart';

/// Ustawienia: tryb sieciowy/offline (#5), klucz API, model, dostępność,
/// głosy, personalizacja, wsparcie (#21), planer (#7).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SwitchListTile(
            title: const Text('Tryb sieciowy (online)',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text(
                'OFF = inferencja w 100% na urządzeniu (#5)',
                style: TextStyle(color: Colors.grey)),
            value: state.onlineMode,
            activeColor: AppColors.red,
            onChanged: (v) => state.setOnlineMode(v),
          ),
          const Divider(color: AppColors.surface),
          _ApiSection(state: state),
          const Divider(color: AppColors.surface),
          ListTile(
            leading: const Icon(Icons.tune, color: AppColors.red),
            title: const Text('Ustawienia wszystkich modułów',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Konfiguracja każdego z 22 modułów',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () =>
                Navigator.pushNamed(context, AppRouter.moduleSettings),
          ),
          ListTile(
            leading: const Icon(Icons.model_training, color: AppColors.red),
            title: const Text('Aktywny model',
                style: TextStyle(color: AppColors.white)),
            subtitle: Text(state.activeModel,
                style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _pickModel(context, state),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over, color: AppColors.red),
            title: const Text('Biblioteka głosów',
                style: TextStyle(color: AppColors.white)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.voiceLibrary),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy, color: AppColors.red),
            title: const Text('Personalizacja agenta',
                style: TextStyle(color: AppColors.white)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.agent),
          ),
          ListTile(
            leading: const Icon(Icons.schedule, color: AppColors.red),
            title: const Text('Planer publikacji',
                style: TextStyle(color: AppColors.white)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.planner),
          ),
          ListTile(
            leading: const Icon(Icons.lock, color: AppColors.red),
            title: const Text('Szyfrowany komunikator (E2E)',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Połączenia grupowe, szyfrowanie end-to-end',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.messenger),
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline, color: AppColors.red),
            title: const Text('Modele lokalne (GGUF)',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Pobierz i załaduj modele (#4)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.models),
          ),
          ListTile(
            leading: const Icon(Icons.radio, color: AppColors.red),
            title: const Text('Radio społecznościowe',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Wspólna kolejka audio + synchronizacja (#13)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.radio),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings, color: AppColors.red),
            title: const Text('Administracja (RBAC)',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Role, uprawnienia, użytkownicy (#15)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.admin),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check, color: AppColors.red),
            title: const Text('Nadzór i moderacja',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Kolejka treści do zatwierdzenia (#16)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.moderation),
          ),
          ListTile(
            leading: const Icon(Icons.code, color: AppColors.red),
            title: const Text('Asystent kodowania',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Pisze nową logikę na życzenie (#10)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.coder),
          ),
          ListTile(
            leading: const Icon(Icons.campaign, color: AppColors.red),
            title: const Text('Ogłoszenia i alerty',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Priorytety + kanały powiadomień (#17)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () =>
                Navigator.pushNamed(context, AppRouter.announcements),
          ),
          ListTile(
            leading: const Icon(Icons.forum, color: AppColors.red),
            title: const Text('Agent w komentarzach',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Auto-odpowiedzi po publikacji (#18)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.comments),
          ),
          ListTile(
            leading: const Icon(Icons.auto_fix_high, color: AppColors.red),
            title: const Text('Samonaprawa i iniekcja kodu',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Dynamiczne ładowanie klas w locie (#11)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.selfHeal),
          ),
          ListTile(
            leading: const Icon(Icons.favorite, color: AppColors.red),
            title: const Text('Wesprzyj projekt',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Dobrowolne wpłaty (#21)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.support),
          ),
          const Divider(color: AppColors.surface),
          ListTile(
            leading: const Icon(Icons.smart_toy, color: AppColors.red),
            title: const Text('Agent automatyzacji',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text(
                'Wieloetapowe zadania w języku naturalnym (pętla AI)',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.automation),
          ),
          ListTile(
            leading: const Icon(Icons.telegram, color: AppColors.red),
            title: const Text('Telegram (zdalny dostęp)',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text('Wydawanie poleceń i monitorowanie postępu',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.pushNamed(context, AppRouter.telegram),
          ),
          ListTile(
            leading: const Icon(Icons.accessibility, color: AppColors.red),
            title: const Text('Usługa sterowania ekranem',
                style: TextStyle(color: AppColors.white)),
            subtitle: const Text(
                'Włącz "Screen Control" w ustawieniach dostępności (#8)',
                style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _pickModel(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in state.availableModels)
              ListTile(
                title: Text(m, style: const TextStyle(color: AppColors.white)),
                trailing: m == state.activeModel
                    ? const Icon(Icons.check, color: AppColors.red)
                    : null,
                onTap: () {
                  state.setActiveModel(m);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Sekcja konfiguracji dostawcy AI: klucz API + Base URL (#4, #5).
class _ApiSection extends StatefulWidget {
  final AppState state;
  const _ApiSection({required this.state});

  @override
  State<_ApiSection> createState() => _ApiSectionState();
}

class _ApiSectionState extends State<_ApiSection> {
  late final TextEditingController _apiCtl;
  late final TextEditingController _urlCtl;

  @override
  void initState() {
    super.initState();
    _apiCtl = TextEditingController(text: widget.state.apiKey);
    _urlCtl = TextEditingController(text: widget.state.baseUrl);
  }

  @override
  void dispose() {
    _apiCtl.dispose();
    _urlCtl.dispose();
    super.dispose();
  }

  Widget _providerChip(String label, String url) {
    return ActionChip(
      backgroundColor: AppColors.black,
      label: Text(label, style: const TextStyle(color: AppColors.white)),
      onPressed: () => setState(() => _urlCtl.text = url),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 4),
          child: Text(
            'Dostawca AI (klucz API / Base URL)',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        // Chipy szybkiego wyboru dostawcy.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 8,
            children: [
              _providerChip('OpenRouter', 'https://openrouter.ai/api/v1'),
              _providerChip('DeepSeek', 'https://api.deepseek.com'),
              _providerChip('OpenAI', 'https://api.openai.com/v1'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _apiCtl,
            obscureText: true,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(
              labelText: 'Klucz API',
              hintText: 'np. sk-or-...',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _urlCtl,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://openrouter.ai/api/v1',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.save, color: AppColors.white),
              label: const Text('Zapisz'),
              onPressed: () {
                widget.state.setApiKey(_apiCtl.text.trim());
                widget.state.setBaseUrl(_urlCtl.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Zapisano konfigurację dostawcy AI')),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
