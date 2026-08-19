import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../services/coder/coder_service.dart';
import '../../state/app_state.dart';

/// Asystent kodowania (#10): pisze nową logikę na życzenie użytkownika.
class CoderScreen extends StatefulWidget {
  const CoderScreen({super.key});

  @override
  State<CoderScreen> createState() => _CoderScreenState();
}

class _CoderScreenState extends State<CoderScreen> {
  final _desc = TextEditingController();
  final _lang = TextEditingController(text: 'dart');
  final _coder = CoderService();
  String _output = '';
  bool _busy = false;

  @override
  void dispose() {
    _desc.dispose();
    _lang.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final state = context.read<AppState>();
    setState(() => _busy = true);
    final code = await _coder.generateCode(
      online: state.onlineMode,
      model: state.activeModel,
      language: _lang.text.trim().isEmpty ? 'dart' : _lang.text.trim(),
      description: _desc.text.trim(),
    );
    setState(() {
      _output = code;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asystent kodowania')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lang,
                        style: const TextStyle(color: AppColors.white),
                        decoration: const InputDecoration(
                            labelText: 'Język (dart/kotlin/…)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _busy ? null : _generate,
                      child: Text(_busy ? 'Generuję…' : 'Generuj kod'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _desc,
                  style: const TextStyle(color: AppColors.white),
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Opisz logikę do napisania…',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surface),
          Expanded(
            child: _output.isEmpty
                ? const Center(
                    child: Text(
                      'Wygenerowany kod pojawi się tutaj.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surface),
                      ),
                      child: SelectableText(
                        _output,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _output.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.red,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _output));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Skopiowano kod do schowka')),
                );
              },
              icon: const Icon(Icons.copy, color: AppColors.white),
              label: const Text('Kopiuj',
                  style: TextStyle(color: AppColors.white)),
            ),
    );
  }
}
