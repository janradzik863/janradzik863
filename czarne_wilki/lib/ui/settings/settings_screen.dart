import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../engine/engine_manager.dart';
import '../../services/app_services.dart';
import '../../services/backup_service.dart';
import '../../services/files_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BackupService _backup = BackupService();
  final FilesService _files = FilesService();
  bool _includeApiKeys = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final engines = context.watch<EngineManager>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tryb Sieciowy'),
            subtitle: const Text(
              'Włączony: chmura i pobieranie modeli.\n'
              'Wyłączony: aplikacja pracuje w 100% lokalnie.',
              style: TextStyle(fontSize: 12, color: CwColors.whiteDim),
            ),
            value: engines.online,
            activeColor: CwColors.crimson,
            onChanged: (v) => engines.setOnline(v),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.memory_outlined, color: CwColors.crimson),
            title: const Text('Aktywny model'),
            subtitle: Text(
              engines.activeModel?.displayName ??
                  'brak — wybierz w ekranie Modeli',
              style: const TextStyle(fontSize: 12, color: CwColors.whiteDim),
            ),
          ),
          const Divider(),

          // ------------------------------------- kopia zapasowa / synchronizacja
          _BackupCard(
            busy: _busy,
            includeApiKeys: _includeApiKeys,
            onIncludeKeys: (v) => setState(() => _includeApiKeys = v),
            onExport: _export,
            onImport: _import,
          ),
          const SizedBox(height: 12),

          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lock_outline, size: 16, color: CwColors.crimson),
                    SizedBox(width: 8),
                    Text('PRYWATNOŚĆ',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: CwColors.crimson)),
                  ]),
                  SizedBox(height: 8),
                  Text(
                    '• Historia rozmów: lokalna baza SQLite na urządzeniu.\n'
                    '• Klucze API: przechowywane lokalnie, wysyłane wyłącznie '
                    'do wybranego dostawcy.\n'
                    '• Tryb Offline: zerowe połączenia sieciowe.\n'
                    '• Automatyzacja: jawny dziennik każdej akcji agenta.\n'
                    '• Kopia zapasowa: zwykły plik JSON przenoszony ręcznie — '
                    'bez serwerów pośrednich.',
                    style: TextStyle(fontSize: 12, color: CwColors.whiteDim),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CZARNE WILKI',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 3)),
                  SizedBox(height: 4),
                  Text(
                    'Wersja 0.1.0 — prywatny asystent AI.\n'
                    'Flutter + Kotlin (usługi dostępności Androida),\n'
                    'llama.cpp dla modeli lokalnych GGUF.',
                    style: TextStyle(fontSize: 12, color: CwColors.whiteDim),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ eksport

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = await _backup.create(includeApiKeys: _includeApiKeys);
      final stamp = DateTime.now();
      final name = 'czarne_wilki_backup_'
          '${stamp.year}${_two(stamp.month)}${_two(stamp.day)}_'
          '${_two(stamp.hour)}${_two(stamp.minute)}.json';
      final saved = await _files.saveTextFile(fileName: name, content: json);
      if (!mounted) return;
      if (saved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kopia zapisana: $saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eksport nie powiódł się: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------- import

  Future<void> _import() async {
    setState(() => _busy = true);
    BackupSummary? summary;
    try {
      final json = await _files.pickTextFile();
      if (json == null) return;
      summary = await _backup.inspect(json);
    } on BackupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nie udało się odczytać pliku: $e')));
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted || summary == null) return;

    // Dialog decyzji: co dokładnie zaimportować.
    var doConversations = true;
    var doModels = true;
    var doProfile = summary.hasAgentProfile;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: CwColors.surface,
          title: const Text('Import kopii zapasowej'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rozmowy: ${summary.totalConversations} '
                '(nowych: ${summary.newConversations}, '
                'duplikaty: ${summary.duplicates})\n'
                'Modele: ${summary.modelCount}\n'
                'Profil agenta: ${summary.hasAgentProfile ? "dostępny" : "brak"}'
                '${summary.hasApiKeys ? "\n⚠ Plik zawiera klucze API" : ""}',
                style: const TextStyle(fontSize: 13, color: CwColors.whiteDim),
              ),
              const SizedBox(height: 10),
              _ImportCheckbox(
                label: 'Rozmowy',
                value: doConversations,
                onChanged: (v) => setDialog(() => doConversations = v ?? false),
              ),
              _ImportCheckbox(
                label: 'Modele (bez plików GGUF — wskaż ponownie)',
                value: doModels,
                onChanged: (v) => setDialog(() => doModels = v ?? false),
              ),
              if (summary.hasAgentProfile)
                _ImportCheckbox(
                  label: 'Profil agenta (nadpisuje obecny)',
                  value: doProfile,
                  onChanged: (v) => setDialog(() => doProfile = v ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Importuj'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await _backup.restore(
        summary,
        conversations: doConversations,
        models: doModels,
        agentProfile: doProfile,
      );
      // Odśwież kontrolery (profil, czat).
      if (mounted) {
        await context.read<AgentProfileController>().load();
        await context.read<ChatController>().reloadFromDb();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Zaimportowano: ${result.importedConversations} rozmów, '
              '${result.importedModels} modeli '
              '(pominięto duplikatów: ${result.skippedDuplicates}).'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import nie powiódł się: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.busy,
    required this.includeApiKeys,
    required this.onIncludeKeys,
    required this.onExport,
    required this.onImport,
  });

  final bool busy;
  final bool includeApiKeys;
  final ValueChanged<bool> onIncludeKeys;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.sync_alt_outlined, size: 16, color: CwColors.crimson),
              SizedBox(width: 8),
              Text('KOPIA ZAPASOWA I SYNCHRONIZACJA (BEZ CHMURY)',
                  style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.1,
                      color: CwColors.crimson)),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Zapisz historię, modele i profil agenta do pliku JSON i przenieś '
              'go między telefonem a komputerem (kabel, pendrive). Import '
              'scala dane i pomija duplikaty.',
              style: TextStyle(fontSize: 12, color: CwColors.whiteDim),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: CwColors.crimson,
              title: const Text('Dołącz klucze API',
                  style: TextStyle(fontSize: 13)),
              subtitle: const Text(
                  'Plik będzie zawierał sekrety — przechowuj go bezpiecznie.',
                  style: TextStyle(fontSize: 11, color: CwColors.whiteDim)),
              value: includeApiKeys,
              onChanged: onIncludeKeys,
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: CwColors.crimson),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text('Eksportuj'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onImport,
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Importuj'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ImportCheckbox extends StatelessWidget {
  const _ImportCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: CwColors.crimson,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: onChanged,
    );
  }
}
