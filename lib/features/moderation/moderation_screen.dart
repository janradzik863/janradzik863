import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/rbac.dart';
import '../../services/moderation/moderation_service.dart';

/// Panel nadzoru i moderacji treści (#16) — kolejka materiałów do zatwierdzenia
/// przez administratora/moderatora (główny kontroler jakości, #22).
class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationService>();
    final auth = context.watch<AuthService>();

    final canModerate = auth.can(Permission.moderateContent) ||
        auth.can(Permission.approveMaterials);

    return Scaffold(
      appBar: AppBar(title: const Text('Nadzór i moderacja')),
      body: !canModerate
          ? const Center(
              child: Text(
                'Brak uprawnień moderacyjnych.\n'
                'Wymagana rola moderatora lub administratora (#15/#16).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : mod.queue.isEmpty
              ? const Center(
                  child: Text('Kolejka moderacji jest pusta.',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: mod.queue.length,
                  itemBuilder: (c, i) {
                    final item = mod.queue[i];
                    return Card(
                      color: AppColors.surface,
                      child: ListTile(
                        leading: Icon(
                          item.kind.name == 'image'
                              ? Icons.image
                              : Icons.article,
                          color: AppColors.red,
                        ),
                        title: Text(item.title,
                            style: const TextStyle(color: AppColors.white)),
                        subtitle: Text(
                          '${item.author} · ${item.status.name}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: item.status == ItemStatus.pending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Odrzuć',
                                    icon: const Icon(Icons.close,
                                        color: Colors.grey),
                                    onPressed: () => mod.reject(item.id),
                                  ),
                                  IconButton(
                                    tooltip: 'Zatwierdź',
                                    icon: const Icon(Icons.check_circle,
                                        color: AppColors.red),
                                    onPressed: () => mod.approve(item.id),
                                  ),
                                ],
                              )
                            : Icon(
                                item.status == ItemStatus.approved
                                    ? Icons.verified
                                    : Icons.cancel,
                                color: item.status == ItemStatus.approved
                                    ? AppColors.red
                                    : Colors.grey,
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
