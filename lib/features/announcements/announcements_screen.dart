import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/rbac.dart';
import '../../services/notifications/announcements_service.dart';

/// Moduł ogłoszeń i alertów priorytetowych (#17).
class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AnnouncementsService>();
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ogłoszenia i alerty')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: svc.items.length,
        itemBuilder: (c, i) {
          final a = svc.items[i];
          return Card(
            color: AppColors.surface,
            child: ListTile(
              leading: Icon(
                _iconFor(a.priority),
                color: a.priority == Priority.high ||
                        a.priority == Priority.critical
                    ? AppColors.red
                    : Colors.grey,
              ),
              title: Text(a.title,
                  style: const TextStyle(
                      color: AppColors.white, fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.body, style: const TextStyle(color: Colors.grey)),
                  Text('priorytet: ${a.priority.name}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: auth.can(Permission.publishPosts)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.red,
              onPressed: () => _publish(context, svc),
              icon: const Icon(Icons.campaign, color: AppColors.white),
              label: const Text('Nowe ogłoszenie',
                  style: TextStyle(color: AppColors.white)),
            )
          : null,
    );
  }

  IconData _iconFor(Priority p) {
    switch (p) {
      case Priority.critical:
      case Priority.high:
        return Icons.priority_high;
      case Priority.normal:
        return Icons.campaign;
      case Priority.low:
        return Icons.info_outline;
    }
  }

  void _publish(BuildContext context, AnnouncementsService svc) {
    final titleCtl = TextEditingController();
    final bodyCtl = TextEditingController();
    var priority = Priority.normal;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Nowe ogłoszenie',
              style: TextStyle(color: AppColors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                style: const TextStyle(color: AppColors.white),
                decoration: const InputDecoration(labelText: 'Tytuł'),
              ),
              TextField(
                controller: bodyCtl,
                style: const TextStyle(color: AppColors.white),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Treść'),
              ),
              DropdownButton<Priority>(
                value: priority,
                dropdownColor: AppColors.surface,
                items: [
                  for (final p in Priority.values)
                    DropdownMenuItem(
                      value: p,
                      child: Text(p.name,
                          style: const TextStyle(color: AppColors.white)),
                    ),
                ],
                onChanged: (v) => setState(() => priority = v ?? priority),
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
                svc.publish(
                  title: titleCtl.text.trim(),
                  body: bodyCtl.text.trim(),
                  priority: priority,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Opublikuj'),
            ),
          ],
        ),
      ),
    );
  }
}
