import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../state/app_state.dart';

/// Personalizacja agenta (#9): nazwa, rola, instrukcje systemowe (System Prompt).
class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _prompt;

  @override
  void initState() {
    super.initState();
    final a = context.read<AppState>().agent;
    _name = TextEditingController(text: a.name);
    _role = TextEditingController(text: a.role);
    _prompt = TextEditingController(text: a.systemPrompt);
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personalizacja agenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(labelText: 'Nazwa agenta'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _role,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(labelText: 'Rola'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prompt,
            style: const TextStyle(color: AppColors.white),
            maxLines: 8,
            decoration:
                const InputDecoration(labelText: 'Instrukcje systemowe (System Prompt)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              context.read<AppState>().setAgent(
                    context.read<AppState>().agent.copyWith(
                          name: _name.text.trim(),
                          role: _role.text.trim(),
                          systemPrompt: _prompt.text.trim(),
                        ),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Zapisano konfigurację agenta')),
              );
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }
}
