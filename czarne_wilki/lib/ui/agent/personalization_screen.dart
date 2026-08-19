import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _sys;

  @override
  void initState() {
    super.initState();
    final p = context.read<AgentProfileController>().profile;
    _name = TextEditingController(text: p.name);
    _role = TextEditingController(text: p.role);
    _sys = TextEditingController(text: p.systemPrompt);
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _sys.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgentProfileController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizacja agenta'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Zdefiniuj, kim jest Twój agent: imię, rola i instrukcja systemowa '
            '(System Prompt) stosowana przy każdej rozmowie i zadaniu.',
            style: TextStyle(color: CwColors.whiteDim, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Imię agenta'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _role,
            decoration: const InputDecoration(
                labelText: 'Rola (np. doradca, tłumacz, szef sztabu)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sys,
            minLines: 6,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'Instrukcja systemowa (System Prompt)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          const Text('TEMPERATURA (kreatywność)',
              style: TextStyle(
                  fontSize: 11, letterSpacing: 1.5, color: CwColors.whiteDim)),
          Slider(
            value: ctrl.profile.temperature,
            min: 0.0,
            max: 1.5,
            activeColor: CwColors.crimson,
            label: ctrl.profile.temperature.toStringAsFixed(1),
            onChanged: (v) => ctrl.save(
              ctrl.profile.copyWith(temperature: v),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PODGLĄD PROMPTU SYSTEMOWEGO',
                      style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 1.2,
                          color: CwColors.crimson)),
                  const SizedBox(height: 6),
                  Text(
                    AgentProfile(
                      name: _name.text,
                      role: _role.text,
                      systemPrompt: _sys.text,
                    ).effectiveSystemPrompt,
                    style:
                        const TextStyle(fontSize: 12, color: CwColors.whiteDim),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await ctrl.save(AgentProfile(
                name: _name.text.trim(),
                role: _role.text.trim(),
                systemPrompt: _sys.text.trim(),
                temperature: ctrl.profile.temperature,
              ));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Profil agenta zapisany.')));
              }
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Zapisz profil'),
          ),
        ],
      ),
    );
  }
}
