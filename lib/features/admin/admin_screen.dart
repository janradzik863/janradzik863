import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/rbac.dart';

/// Panel administratora: zarządzanie użytkownikami i rolami (RBAC, #15).
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final me = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Administracja (RBAC)')),
      body: Column(
        children: [
          _ActiveUserBar(auth: auth),
          const Divider(height: 1, color: AppColors.surface),
          Expanded(
            child: auth.can(Permission.manageUsers)
                ? _UserList(auth: auth)
                : const Center(
                    child: Text(
                      'Brak uprawnień do zarządzania użytkownikami.\n'
                      'Wymagana rola administratora (#15).',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActiveUserBar extends StatelessWidget {
  final AuthService auth;
  const _ActiveUserBar({required this.auth});

  @override
  Widget build(BuildContext context) {
    final me = auth.currentUser;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.badge, color: AppColors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(me?.name ?? '—',
                    style: const TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.bold)),
                Text('Rola: ${me?.role.name ?? '—'}',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          // Przełącznik tożsamości (demo RBAC)
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz, color: AppColors.white),
            color: AppColors.surface,
            tooltip: 'Przełącz użytkownika',
            onSelected: (id) => auth.switchUser(id),
            itemBuilder: (_) => [
              for (final u in auth.users)
                PopupMenuItem(
                  value: u.id,
                  child: Text('${u.name} (${u.role.name})',
                      style: const TextStyle(color: AppColors.white)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final AuthService auth;
  const _UserList({required this.auth});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final u in auth.users)
          Card(
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(Icons.person, color: AppColors.red),
              title: Text(u.name,
                  style: const TextStyle(color: AppColors.white)),
              subtitle: Text('rola: ${u.role.name}',
                  style: const TextStyle(color: Colors.grey)),
              trailing: DropdownButton<Role>(
                value: u.role,
                underline: const SizedBox(),
                dropdownColor: AppColors.surface,
                iconEnabledColor: AppColors.white,
                items: [
                  for (final r in Role.values)
                    DropdownMenuItem(
                      value: r,
                      child: Text(r.name,
                          style: const TextStyle(color: AppColors.white)),
                    ),
                ],
                onChanged: (r) {
                  if (r == null) return;
                  final ok = auth.assignRole(u.id, r);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Brak uprawnień lub próba zmiany własnej roli.')),
                    );
                  }
                },
              ),
            ),
          ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Dodaj użytkownika'),
          onPressed: () => _addUser(context),
        ),
      ],
    );
  }

  void _addUser(BuildContext context) {
    final nameCtl = TextEditingController();
    var role = Role.member;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Nowy użytkownik',
              style: TextStyle(color: AppColors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtl,
                style: const TextStyle(color: AppColors.white),
                decoration: const InputDecoration(labelText: 'Nazwa'),
              ),
              DropdownButton<Role>(
                value: role,
                dropdownColor: AppColors.surface,
                items: [
                  for (final r in Role.values)
                    DropdownMenuItem(
                      value: r,
                      child: Text(r.name,
                          style: const TextStyle(color: AppColors.white)),
                    ),
                ],
                onChanged: (r) => setState(() => role = r ?? role),
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
                auth.addUser(nameCtl.text.trim(), role);
                Navigator.pop(ctx);
              },
              child: const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
  }
}
