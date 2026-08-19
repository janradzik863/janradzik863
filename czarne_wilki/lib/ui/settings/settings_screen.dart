import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../engine/engine_manager.dart';
import '../../services/app_services.dart';
import '../../services/rbac_service.dart';
import '../../services/sync_bridge.dart';
import '../../services/backup_service.dart';
import '../../services/files_service.dart';

/// Ustawienia aplikacji: tryb pracy (pkt 5), synchronizacja (pkt 1),
/// RBAC (pkt 15), tryb bez maski (pkt 19), kopia zapasowa.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backup = BackupService();
  bool _busy = false;
  bool _includeApiKeys = false;

  // Sync bridge
  final _hostCtrl = TextEditingController(text: '192.168.1.100');

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engines = context.watch<EngineManager>();
    final profile = context.watch<AgentProfileController>();
    final rbac = context.watch<RbacService>();
    final sync = context.watch<SyncBridge>();

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
          // --- Punkt 5: Przełącznik trybu ---
          const Text('TRYB PRACY',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.crimson)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: CwColors.online,
                    title: Text(
                      engines.online ? 'TRYB SIECIOWY' : 'TRYB OFFLINE',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: engines.online
                            ? CwColors.online
                            : CwColors.offline,
                      ),
                    ),
                    subtitle: Text(
                      engines.online
                          ? 'Połączenia z chmurą dozwolone — dane mogą '
                              'opuszczać urządzenie.'
                          : '100% na urządzeniu — żadne dane nie wychodzą na '
                              'zewnątrz. Wymaga modelu lokalnego GGUF.',
                      style:
                          const TextStyle(fontSize: 12, color: CwColors.whiteDim),
                    ),
                    value: engines.online,
                    onChanged: (v) => engines.setOnline(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Punkt 19: Tryb bez maski ---
          const Text('TRYB BEZ MASKI',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.crimson)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: CwColors.crimson,
                title: const Text('Zniesienie filtrów AI',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'Otwarte modele pracują bez wbudowanych ograniczeń. '
                  'Odpowiedzialność za treści ponosi wyłącznie użytkownik.',
                  style: TextStyle(fontSize: 12, color: CwColors.whiteDim),
                ),
                value: profile.profile.unfilteredMode,
                onChanged: (v) =>
                    profile.save(profile.profile.copyWith(unfilteredMode: v)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Punkt 1: Synchronizacja międzyplatformowa ---
          const Text('SYNCHRONIZACJA URZĄDZEŃ',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.crimson)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        sync.connected
                            ? Icons.link
                            : Icons.link_off,
                        color: sync.connected
                            ? CwColors.online
                            : CwColors.whiteDim,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sync.statusText,
                          style: TextStyle(
                            fontSize: 13,
                            color: sync.connected
                                ? CwColors.online
                                : CwColors.whiteDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: sync.connected
                              ? null
                              : () => sync.startServer(),
                          child: const Text('Serwer (desktop)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: sync.connected
                              ? () => sync.stop()
                              : null,
                          child: const Text('Rozłącz'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hostCtrl,
                          decoration: const InputDecoration(
                            hintText: 'IP serwera',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: sync.connected
                            ? null
                            : () => sync.connectToServer(_hostCtrl.text.trim()),
                        child: const Text('Połącz'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Punkt 15: RBAC ---
          const Text('KONTROLA DOSTĘPU (RBAC)',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.crimson)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rbac.isLoggedIn) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: CwColors.crimsonDark,
                        child: Icon(Icons.person,
                            color: CwColors.white, size: 20),
                      ),
                      title: Text(rbac.currentUser!.username,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        'Rola: ${rbac.currentUser!.role.name.toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 12, color: CwColors.crimson),
                      ),
                      trailing: OutlinedButton(
                        onPressed: rbac.logout,
                        child: const Text('Wyloguj'),
                      ),
                    ),
                    if (rbac.isAdmin)
                      FilledButton.icon(
                        onPressed: () => _addUserDialog(context, rbac),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Dodaj użytkownika'),
                      ),
                  ] else if (!rbac.setupComplete) ...[
                    const Text(
                      'Pierwszy uruchomienie — utwórz konto administratora.',
                      style: TextStyle(fontSize: 13, color: CwColors.whiteDim),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => _setupAdmin(context, rbac),
                      child: const Text('Utwórz administratora'),
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: () => _loginDialog(context, rbac),
                      child: const Text('Zaloguj się'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Kopia zapasowa ---
          const Text('KOPIA ZAPASOWA',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.crimson)),
          const SizedBox(height: 8),
          _BackupCard(
            busy: _busy,
            includeApiKeys: _includeApiKeys,
            onIncludeKeys: (v) => setState(() => _includeApiKeys = v),
            onExport: _export,
            onImport: _import,
          ),
        ],
      ),
    );
  }

  void _setupAdmin(BuildContext context, RbacService rbac) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CwColors.surface,
        title: const Text('Utwórz administratora'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(hintText: 'Nazwa użytkownika'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Hasło'),
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
              if (userCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) return;
              await rbac.createAdmin(userCtrl.text.trim(), passCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Utwórz'),
          ),
        ],
      ),
    );
  }

  void _loginDialog(BuildContext context, RbacService rbac) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CwColors.surface,
        title: const Text('Logowanie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(hintText: 'Nazwa użytkownika'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Hasło'),
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
              final ok =
                  await rbac.login(userCtrl.text.trim(), passCtrl.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Nieprawidłowy login lub hasło.')),
                  );
                }
              }
            },
            child: const Text('Zaloguj'),
          ),
        ],
      ),
    );
  }

  void _addUserDialog(BuildContext context, RbacService rbac) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var role = 'user';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: CwColors.surface,
          title: const Text('Dodaj użytkownika'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(hintText: 'Nazwa'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Hasło'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: role,
                dropdownColor: CwColors.surfaceAlt,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(
                      value: 'moderator', child: Text('Moderator')),
                  DropdownMenuItem(value: 'user', child: Text('Użytkownik')),
                  DropdownMenuItem(value: 'viewer', child: Text('Czytelnik')),
                ],
                onChanged: (v) => setDialog(() => role = v ?? 'user'),
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
                if (userCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) {
                  return;
                }
                final userRole = switch (role) {
                  'admin' => UserRole.admin,
                  'moderator' => UserRole.moderator,
                  'viewer' => UserRole.viewer,
                  _ => UserRole.user,
                };
                await rbac.addUser(
                    userCtrl.text.trim(), passCtrl.text, userRole);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
  }

  void _export() async {
    setState(() => _busy = true);
    try {
      await _backup.export(includeApiKeys: _includeApiKeys);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kopia zapasowa wyeksportowana.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eksport nie powiódł się: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _import() async {
    setState(() => _busy = true);
    try {
      final summary = await _backup.pickAndAnalyze();
      if (summary == null) {
        setState(() => _busy = false);
        return;
      }

      if (mounted) {
        await context.read<AgentProfileController>().load();
        await context.read<ChatController>().reloadFromDb();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import zakończony.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import nie powiódł się: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: CwColors.crimson),
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
