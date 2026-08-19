import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../automation/task_agent.dart';
import '../../core/theme.dart';
import '../../services/app_services.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  final _goal = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<AutomationController>().refreshConnection());
  }

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auto = context.watch<AutomationController>();
    final running = auto.agentState == AgentState.running;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Automatyzacja urządzenia'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stan usługi dostępności
          Card(
            child: ListTile(
              leading: Icon(
                auto.serviceConnected
                    ? Icons.verified_user
                    : Icons.gpp_bad_outlined,
                color: auto.serviceConnected
                    ? CwColors.online
                    : CwColors.crimson,
              ),
              title: Text(
                auto.serviceConnected
                    ? 'Usługa „Czarne Wilki — Sterowanie Ekranem” aktywna'
                    : 'Usługa dostępności jest wyłączona',
                style: const TextStyle(fontSize: 13.5),
              ),
              subtitle: const Text(
                'Ustawienia → Dostępność → Czarne Wilki',
                style: TextStyle(fontSize: 11, color: CwColors.whiteDim),
              ),
              trailing: TextButton(
                onPressed: () async {
                  await auto.openSettings();
                  await Future<void>.delayed(const Duration(seconds: 2));
                  await auto.refreshConnection();
                },
                child: const Text('Otwórz'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cel zadania
          TextField(
            controller: _goal,
            enabled: !running,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Polecenie dla agenta',
              hintText: 'np. „otwórz ustawienia i włącz tryb samolotowy”',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: running
                      ? null
                      : () {
                          final g = _goal.text.trim();
                          if (g.isEmpty) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                          auto.run(g);
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CwColors.crimson,
                    side: const BorderSide(color: CwColors.crimson),
                  ),
                  onPressed: running ? () => auto.stop() : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('STOP'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Polityka — jawna, widoczna
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.shield_outlined, color: CwColors.crimson, size: 16),
                    SizedBox(width: 8),
                    Text('ZASADY DZIAŁANIA',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: CwColors.crimson)),
                  ]),
                  SizedBox(height: 8),
                  Text(
                    'Agent działa wyłącznie na Twoim urządzeniu. Nie publikuje '
                    'treści, nie komentuje i nie udaje człowieka wobec innych '
                    'ludzi — treści dla innych przygotowuje jako szkic do '
                    'Twojej własnoręcznej wysyłki. Każda akcja jest logowana '
                    'poniżej.',
                    style:
                        TextStyle(fontSize: 12, color: CwColors.whiteDim),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Log akcji — jawność operacji
          if (auto.log.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 16, color: CwColors.whiteDim),
                SizedBox(width: 8),
                Text('DZIENNIK AKCJI',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: CwColors.whiteDim)),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in auto.log.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.time.hour.toString().padLeft(2, '0')}:'
                      '${entry.time.minute.toString().padLeft(2, '0')}:'
                      '${entry.time.second.toString().padLeft(2, '0')}  ',
                      style: const TextStyle(
                          fontSize: 10.5, color: CwColors.whiteDim),
                    ),
                    Expanded(
                      child: Text(
                        entry.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: entry.ok ? CwColors.white : CwColors.crimson,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
