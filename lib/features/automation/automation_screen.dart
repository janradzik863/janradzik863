import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/constants.dart';
import '../../services/agent/agent_controller.dart';
import '../../services/settings/app_settings.dart';
import '../../services/telegram/telegram_service.dart';
import '../../state/app_state.dart';

/// Ekran agenta automatyzacji Androida — wieloetapowe zadania w języku
/// naturalnym (pętla sprzężenia zwrotnego z natywną usługą dostępności).
class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  final _controller = AgentController();
  final _command = TextEditingController();
  final _speech = SpeechToText();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onAgentUpdate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Zdalny dostęp: polecenia z Telegrama uruchamiają agenta automatycznie.
    final telegram = context.read<TelegramService>();
    telegram.onCommand ??= (cmd) {
      if (mounted) {
        _command.text = cmd.text;
        _run();
      }
    };
  }

  @override
  void dispose() {
    _controller.removeListener(_onAgentUpdate);
    _controller.dispose();
    _command.dispose();
    _speech.cancel();
    super.dispose();
  }

  void _onAgentUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _run() async {
    final text = _command.text.trim();
    if (text.isEmpty || _controller.running) return;
    final state = context.read<AppState>();
    final settings = context.read<AppSettings>();
    _controller.maxSteps = settings.get<int>('agentMaxSteps');
    _controller.stepDelay =
        Duration(milliseconds: settings.get<int>('agentStepDelayMs'));
    await _controller.run(
      command: text,
      online: state.onlineMode,
      model: state.activeModel,
      systemPrompt: state.agent.systemPrompt,
    );
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) => setState(() => _listening = false),
    );
    if (!available) return;
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'pl-PL',
      onResult: (r) {
        if (r.finalResult) {
          _command.text = r.recognizedWords;
          _command.selection =
              TextSelection.collapsed(offset: _command.text.length);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent automatyzacji')),
      body: Column(
        children: [
          _CommandBar(
            controller: _command,
            listening: _listening,
            running: _controller.running,
            onRun: _run,
            onVoice: _toggleVoice,
          ),
          const Divider(height: 1, color: AppColors.surface),
          Expanded(
            child: _controller.steps.isEmpty
                ? const Center(
                    child: Text(
                      'Wydaj polecenie w języku naturalnym,\n'
                      'np. „Otwórz Ustawienia i włącz Wi-Fi".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _controller.steps.length,
                    itemBuilder: (c, i) {
                      final s = _controller.steps[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          s.success
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: s.success ? AppColors.red : Colors.grey,
                          size: 20,
                        ),
                        title: Text('Krok ${i + 1}: ${s.actionDescription}',
                            style: const TextStyle(
                                color: AppColors.white, fontSize: 13)),
                        subtitle: s.note != null
                            ? Text(s.note!,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11))
                            : null,
                      );
                    },
                  ),
          ),
          if (_controller.summary != null)
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.all(12),
              child: Text(
                '✓ ${_controller.summary}',
                style: const TextStyle(color: AppColors.red),
              ),
            ),
          if (_controller.error != null)
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.all(12),
              child: Text(
                '⚠ ${_controller.error}',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommandBar extends StatelessWidget {
  final TextEditingController controller;
  final bool listening;
  final bool running;
  final VoidCallback onRun;
  final VoidCallback onVoice;

  const _CommandBar({
    required this.controller,
    required this.listening,
    required this.running,
    required this.onRun,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: listening
                      ? 'Nasłuchuję…'
                      : 'Polecenie (np. otwórz aplikację i zrób…)',
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                onSubmitted: (_) => onRun(),
              ),
            ),
            IconButton(
              tooltip: 'Głos (mowa → tekst)',
              icon: Icon(
                listening ? Icons.mic : Icons.mic_none,
                color: listening ? AppColors.red : AppColors.white,
              ),
              onPressed: onVoice,
            ),
            IconButton(
              tooltip: 'Uruchom zadanie',
              icon: running
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.red),
                    )
                  : const Icon(Icons.play_circle_fill, color: AppColors.red),
              onPressed: running ? null : onRun,
            ),
          ],
        ),
      ),
    );
  }
}
