import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Planer publikacji (#7): harmonogram dat, godzin i platform docelowych.
/// W wersji produkcyjnej zadania są trwale zapisywane w SQLite (tabela
/// `publication_tasks`) i wykonywane autonomicznie przez usługę dostępności (#8).
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _content = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _platform = 'Telegram';

  static const _platforms = ['Telegram', 'X (Twitter)', 'Facebook', 'Instagram'];

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planer publikacji')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _content,
            style: const TextStyle(color: AppColors.white),
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Treść posta'),
          ),
          const SizedBox(height: 16),
          const Text('Data i godzina',
              style: TextStyle(color: AppColors.white)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(_formatDate(_date),
                style: const TextStyle(color: AppColors.white)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 16),
          const Text('Platforma docelowa',
              style: TextStyle(color: AppColors.white)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _platform,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(),
            items: [
              for (final p in _platforms)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) => setState(() => _platform = v ?? _platform),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.schedule_send),
            label: const Text('Zaplanuj publikację'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Zaplanowano na ${_formatDate(_date)} → $_platform')),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
