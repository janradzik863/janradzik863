import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/announcement_service.dart';
import '../../services/rbac_service.dart';

/// Punkt 17: Moduł ogłoszeń i alertów priorytetowych.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AnnouncementService>().load());
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AnnouncementService>();
    final rbac = context.watch<RbacService>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ogłoszenia'),
            if (svc.unreadCount > 0)
              Text(
                'Nieprzeczytanych: ${svc.unreadCount}',
                style: const TextStyle(fontSize: 11, color: CwColors.crimson),
              ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: svc.items.isEmpty
          ? const Center(
              child: Text('Brak ogłoszeń.',
                  style: TextStyle(color: CwColors.whiteDim)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: svc.items.length,
              itemBuilder: (_, i) {
                final a = svc.items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: a.read ? CwColors.surface : CwColors.surfaceAlt,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => svc.markRead(a.id),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _priorityIcon(a.priority),
                                color: _priorityColor(a.priority),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  a.title,
                                  style: TextStyle(
                                    fontWeight: a.read
                                        ? FontWeight.w400
                                        : FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (!a.read)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: CwColors.crimson,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            a.body,
                            style: const TextStyle(
                                fontSize: 13, color: CwColors.whiteDim),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(a.createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: CwColors.whiteDim),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: rbac.isAdmin
          ? FloatingActionButton(
              backgroundColor: CwColors.crimson,
              onPressed: () => _createAnnouncement(context, svc),
              child: const Icon(Icons.campaign, color: CwColors.white),
            )
          : null,
    );
  }

  IconData _priorityIcon(AnnouncementPriority p) => switch (p) {
        AnnouncementPriority.critical => Icons.warning_amber,
        AnnouncementPriority.high => Icons.priority_high,
        AnnouncementPriority.normal => Icons.info_outline,
      };

  Color _priorityColor(AnnouncementPriority p) => switch (p) {
        AnnouncementPriority.critical => CwColors.crimson,
        AnnouncementPriority.high => CwColors.offline,
        AnnouncementPriority.normal => CwColors.whiteDim,
      };

  void _createAnnouncement(BuildContext context, AnnouncementService svc) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    var priority = AnnouncementPriority.normal;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: CwColors.surface,
          title: const Text('Nowe ogłoszenie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(hintText: 'Tytuł'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Treść ogłoszenia'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<AnnouncementPriority>(
                value: priority,
                dropdownColor: CwColors.surfaceAlt,
                decoration: const InputDecoration(labelText: 'Priorytet'),
                items: const [
                  DropdownMenuItem(
                      value: AnnouncementPriority.normal,
                      child: Text('Normalny')),
                  DropdownMenuItem(
                      value: AnnouncementPriority.high,
                      child: Text('Wysoki')),
                  DropdownMenuItem(
                      value: AnnouncementPriority.critical,
                      child: Text('Krytyczny')),
                ],
                onChanged: (v) =>
                    setDialog(() => priority = v ?? AnnouncementPriority.normal),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                svc.create(
                  title: titleCtrl.text.trim(),
                  body: bodyCtrl.text.trim(),
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
