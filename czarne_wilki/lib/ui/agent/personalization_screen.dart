import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/app_services.dart';

/// Punkt 9: Okno Personalizacji Agenta.
/// Punkt 19: Przełącznik trybu bez maski (unfilteredMode).
class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  late TextEditingController _name;
  late TextEditingController _role;
  late TextEditingController _prompt;
  late double _temp;
  late bool _unfiltered;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AgentProfileController>().profile;
    _name = TextEditingController(text: p.name);
    _role = TextEditingController(text: p.role);
    _prompt = TextEditingController(text: p.systemPrompt);
    _temp = p.temperature;
    _unfiltered = p.unfilteredMode;
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _prompt.dispose();
    super.dispose();
  }

  void _save() {
    final ctrl = context.read<AgentProfileController>();
    ctrl.save(AgentProfile(
      name: _name.text.trim(),
      role: _role.text.trim(),
      systemPrompt: _prompt.text.trim(),
      temperature: _temp,
      unfilteredMode: _unfiltered,
    ));
    setState(() => _changed = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil agenta zapisany.')),
    );
  }

  void _mark() {
    if (!_changed) setState(() => _changed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizacja agenta'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
        actions: [
          if (_changed)
            FilledButton(
              onPressed: _save,
              child: const Text('Zapisz'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: CwLogo(width: 100)),
          const SizedBox(height: 16),
          const Text('TOŻSAMOŚĆ AGENTA',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.crimson)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Imię agenta'),
            onChanged: (_) => _mark(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _role,
            decoration: const InputDecoration(labelText: 'Rola agenta'),
            onChanged: (_) => _mark(),
          ),
          const SizedBox(height: 16),
          const Text('INSTRUKCJA SYSTEMOWA (System Prompt)',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.crimson)),
          const SizedBox(height: 8),
          TextField(
            controller: _prompt,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Wpisz własną instrukcję systemową…\n'
                  'Definiuje charakter, styl i ograniczenia agenta.',
            ),
            onChanged: (_) => _mark(),
          ),
          const SizedBox(height: 16),
          const Text('TEMPERATURA',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.whiteDim)),
          Slider(
            value: _temp,
            min: 0.0,
            max: 2.0,
            divisions: 20,
            activeColor: CwColors.crimson,
            label: _temp.toStringAsFixed(1),
            onChanged: (v) {
              setState(() => _temp = v);
              _mark();
            },
          ),
          Text(
            'Niska (0.0) = precyzyjne odpowiedzi • Wysoka (2.0) = kreatywne',
            style: const TextStyle(fontSize: 11, color: CwColors.whiteDim),
          ),
          const SizedBox(height: 16),

          // Punkt 19: Tryb bez maski
          const Text('TRYB BEZ MASKI',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.crimson)),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              activeColor: CwColors.crimson,
              title: const Text('Zniesienie filtrów AI'),
              subtitle: const Text(
                'Model odpowiada na KAŻDE pytanie bez ograniczeń. '
                'Działa wyłącznie z otwartymi modelami (np. abliterated).',
                style: TextStyle(fontSize: 12, color: CwColors.whiteDim),
              ),
              value: _unfiltered,
              onChanged: (v) {
                setState(() => _unfiltered = v);
                _mark();
              },
            ),
          ),
          const SizedBox(height: 20),

          // Podgląd efektywnego promptu
          const Text('PODGLĄD EFEKTYWNEGO PROMPTU',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: CwColors.whiteDim)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                AgentProfile(
                  name: _name.text.trim(),
                  role: _role.text.trim(),
                  systemPrompt: _prompt.text.trim(),
                  temperature: _temp,
                  unfilteredMode: _unfiltered,
                ).effectiveSystemPrompt,
                style: const TextStyle(
                    fontSize: 12,
                    color: CwColors.whiteDim,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
