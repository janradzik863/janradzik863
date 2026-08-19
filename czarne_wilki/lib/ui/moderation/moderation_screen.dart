import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/moderation_service.dart';
import '../../services/rbac_service.dart';

/// Punkt 16 + 22: Panel nadzoru i moderacji treści / Kontroler jakości.
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ModerationService>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationService>();
    final rbac = context.watch<RbacService>();
    final pending = mod.filterByStatus(ModerationStatus.pending);
    final approved = mod.filterByStatus(ModerationStatus.approved);
    final rejected = mod.filterByStatus(ModerationStatus.rejected);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Moderacja treści'),
            Text(
              'Oczekujących: ${mod.pendingCount}',
              style: const TextStyle(fontSize: 11, color: CwColors.whiteDim),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text('OCZEKUJĄCE NA ZATWIERDZENIE',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.crimson)),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Brak materiałów do moderacji.',
                    style: TextStyle(color: CwColors.whiteDim)),
              ),
            )
          else
            for (final item in pending)
              _ModerationCard(
                item: item,
                canModerate: rbac.canModerate,
                onApprove: () => mod.approve(
                  item.id,
                  rbac.currentUser?.username ?? 'admin',
                ),
                onReject: () => mod.reject(
                  item.id,
                  rbac.currentUser?.username ?? 'admin',
                ),
              ),
          const SizedBox(height: 20),
          const Text('ZATWIERDZONE',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.online)),
          const SizedBox(height: 8),
          for (final item in approved.take(10))
            _ModerationCard(item: item, canModerate: false),
          const SizedBox(height: 20),
          const Text('ODRZUCONE',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.whiteDim)),
          const SizedBox(height: 8),
          for (final item in rejected.take(10))
            _ModerationCard(item: item, canModerate: false),
        ],
      ),
    );
  }
}

class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.item,
    required this.canModerate,
    this.onApprove,
    this.onReject,
  });

  final ModerationItem item;
  final bool canModerate;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: item.status == ModerationStatus.pending
          ? CwColors.surface
          : item.status == ModerationStatus.approved
              ? CwColors.surface
              : CwColors.surfaceAlt,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForType(item.contentType),
                  size: 16,
                  color: CwColors.crimson,
                ),
                const SizedBox(width: 6),
                Text(
                  item.contentType.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      color: CwColors.whiteDim),
                ),
                const Spacer(),
                _StatusBadge(status: item.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.content.length > 200
                  ? '${item.content.substring(0, 200)}…'
                  : item.content,
              style: const TextStyle(fontSize: 13, color: CwColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Źródło: ${item.submittedBy} • '
              '${DateFormat('dd.MM HH:mm').format(item.createdAt)}',
              style: const TextStyle(fontSize: 11, color: CwColors.whiteDim),
            ),
            if (canModerate &&
                item.status == ModerationStatus.pending &&
                onApprove != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Zatwierdź'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Odrzuć'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
        'post' => Icons.article_outlined,
        'comment' => Icons.comment_outlined,
        'message' => Icons.message_outlined,
        _ => Icons.pending_outlined,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ModerationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ModerationStatus.pending => ('OCZEKUJE', CwColors.offline),
      ModerationStatus.approved => ('ZATWIERDZONE', CwColors.online),
      ModerationStatus.rejected => ('ODRZUCONE', CwColors.crimson),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
