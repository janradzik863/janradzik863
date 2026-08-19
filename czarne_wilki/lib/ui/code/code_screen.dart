import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../engine/engine_manager.dart';
import '../../services/code_assistant_service.dart';

/// Punkt 10: Wbudowany Asystent Kodowania.
/// Punkt 11: Mechanizm samonaprawy i iniekcji kodu w locie.
class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final _requestCtrl = TextEditingController();
  String _language = 'dart';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<CodeAssistantService>().load());
  }

  @override
  void dispose() {
    _requestCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = context.watch<CodeAssistantService>();
    final engines = context.watch<EngineManager>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asystent Kodowania'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
        actions: [
          // Języki
          PopupMenuButton<String>(
            tooltip: 'Język',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CwColors.crimson.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _language.toUpperCase(),
                style: const TextStyle(
                    color: CwColors.crimson,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            color: CwColors.surfaceAlt,
            onSelected: (v) => setState(() => _language = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'dart', child: Text('Dart')),
              PopupMenuItem(value: 'kotlin', child: Text('Kotlin')),
              PopupMenuItem(value: 'python', child: Text('Python')),
              PopupMenuItem(value: 'javascript', child: Text('JavaScript')),
              PopupMenuItem(value: 'rust', child: Text('Rust')),
              PopupMenuItem(value: 'sql', child: Text('SQL')),
              PopupMenuItem(value: 'html', child: Text('HTML')),
              PopupMenuItem(value: 'bash', child: Text('Bash')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Pole polecenia
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _requestCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'Opisz kod, który mam wygenerować…\n(np. „Funkcja sortowania bąbelkowego")',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    FilledButton(
                      onPressed: code.busy || engines.engine == null
                          ? null
                          : () {
                              final text = _requestCtrl.text.trim();
                              if (text.isEmpty) return;
                              code.generateCode(
                                engine: engines.engine!,
                                request: text,
                                language: _language,
                              );
                            },
                      child: code.busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: CwColors.white),
                            )
                          : const Text('Generuj'),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      onPressed: code.output.isEmpty || engines.engine == null
                          ? null
                          : () {
                              code.selfRepair(
                                engine: engines.engine!,
                                brokenCode: code.output,
                                errorMessage: 'Napraw błędy i zoptymalizuj',
                                language: _language,
                              );
                            },
                      child: const Text('Napraw',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Wygenerowany kod
          if (code.output.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text('WYGENEROWANY KOD',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          color: CwColors.whiteDim)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Kopiuj',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code.output));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Skopiowano do schowka')),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Zapisz do pliku',
                    icon: const Icon(Icons.save_outlined, size: 18),
                    onPressed: () async {
                      final ext = _extForLang(_language);
                      final path = await code.saveCodeToFile(
                        code.output,
                        'generated_${DateTime.now().millisecondsSinceEpoch}.$ext',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Zapisano: $path')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CwColors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CwColors.crimson.withValues(alpha: 0.3)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    code.output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: CwColors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.code, size: 48, color: CwColors.whiteDim),
                    const SizedBox(height: 12),
                    const Text(
                      'Opisz logikę, którą mam napisać.\nAgent wygeneruje gotowy kod.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CwColors.whiteDim, fontSize: 13),
                    ),
                    if (engines.engine == null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Wybierz model AI w ekranie Modeli.',
                        style: TextStyle(
                            color: CwColors.crimson, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // Historia snippetów
          if (code.snippets.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('HISTORIA',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: CwColors.whiteDim)),
            ),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: code.snippets.length,
                itemBuilder: (_, i) {
                  final s = code.snippets[i];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        _requestCtrl.text = s.title;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Center(
                          child: Text(
                            s.title.length > 30
                                ? '${s.title.substring(0, 30)}…'
                                : s.title,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _extForLang(String lang) => switch (lang) {
        'dart' => 'dart',
        'kotlin' => 'kt',
        'python' => 'py',
        'javascript' => 'js',
        'rust' => 'rs',
        'sql' => 'sql',
        'html' => 'html',
        'bash' => 'sh',
        _ => 'txt',
      };
}
