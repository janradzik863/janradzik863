import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/planner_service.dart';

/// Punkt 7: Moduł Planera Publikacji z harmonogramem dat, godzin i platform.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    Future.microtask(() => context.read<PlannerService>().load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planer Publikacji'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            children: [
              const CwFlagStrip(),
              TabBar(
                controller: _tabs,
                indicatorColor: CwColors.crimson,
                labelColor: CwColors.crimson,
                unselectedLabelColor: CwColors.whiteDim,
                tabs: [
                  Tab(text: 'Szkice (${planner.drafts.length})'),
                  Tab(text: 'Zaplanowane (${planner.scheduled.length})'),
                  Tab(text: 'Opublikowane (${planner.published.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _PostList(posts: planner.drafts, planner: planner, isDraft: true),
          _PostList(posts: planner.scheduled, planner: planner),
          _PostList(posts: planner.published, planner: planner),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: CwColors.crimson,
        onPressed: () => _showCreateDialog(context, planner),
        child: const Icon(Icons.add, color: CwColors.white),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, PlannerService planner) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String platform = 'facebook';
    DateTime scheduledAt = DateTime.now().add(const Duration(hours: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: CwColors.surface,
          title: const Text('Nowy post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(hintText: 'Tytuł'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: 'Treść posta'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: platform,
                  dropdownColor: CwColors.surfaceAlt,
                  decoration: const InputDecoration(labelText: 'Platforma'),
                  items: const [
                    DropdownMenuItem(value: 'facebook', child: Text('Facebook')),
                    DropdownMenuItem(value: 'instagram', child: Text('Instagram')),
                    DropdownMenuItem(value: 'x', child: Text('X (Twitter)')),
                    DropdownMenuItem(value: 'telegram', child: Text('Telegram')),
                    DropdownMenuItem(value: 'tiktok', child: Text('TikTok')),
                  ],
                  onChanged: (v) => setDialog(() => platform = v ?? 'facebook'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Data: ${DateFormat('dd.MM.yyyy HH:mm').format(scheduledAt)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: const Icon(Icons.calendar_today,
                      color: CwColors.crimson, size: 20),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: scheduledAt,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(scheduledAt),
                    );
                    if (time == null) return;
                    setDialog(() {
                      scheduledAt = DateTime(
                          date.year, date.month, date.day, time.hour, time.minute);
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                planner.createPost(
                  title: titleCtrl.text.trim(),
                  content: contentCtrl.text.trim(),
                  platform: platform,
                  scheduledAt: scheduledAt,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Utwórz'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({
    required this.posts,
    required this.planner,
    this.isDraft = false,
  });

  final List<PlannerPost> posts;
  final PlannerService planner;
  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('Brak postów w tej kategorii.',
            style: TextStyle(color: CwColors.whiteDim)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final p = posts[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(p.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${p.platform.toUpperCase()} • '
              '${DateFormat('dd.MM.yyyy HH:mm').format(p.scheduledAt)}',
              style: const TextStyle(fontSize: 12, color: CwColors.whiteDim),
            ),
            trailing: isDraft
                ? IconButton(
                    icon: const Icon(Icons.check_circle_outline,
                        color: CwColors.online),
                    onPressed: () => planner.approve(p.id),
                    tooltip: 'Zatwierdź do publikacji',
                  )
                : null,
            onLongPress: () => planner.deletePost(p.id),
          ),
        );
      },
    );
  }
}
