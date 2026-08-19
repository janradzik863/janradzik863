import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/selfheal/self_heal_service.dart';

/// Ekran samonaprawy i iniekcji kodu w locie (#11).
class SelfHealScreen extends StatefulWidget {
  const SelfHealScreen({super.key});

  @override
  State<SelfHealScreen> createState() => _SelfHealScreenState();
}

class _SelfHealScreenState extends State<SelfHealScreen> {
  final _service = SelfHealService();
  final _dexPath = TextEditingController();
  bool _initialized = false;
  String _status = 'Moduł samonaprawy nieaktywny.';

  @override
  void dispose() {
    _dexPath.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final ok = await _service.init();
    setState(() {
      _initialized = ok;
      _status = ok
          ? 'Samonaprawa aktywna (Android ClassLoader gotowy).'
          : 'Samonaprawa dostępna tylko przez pliki źródłowe (desktop).';
    });
  }

  Future<void> _loadDex() async {
    final path = _dexPath.text.trim();
    if (path.isEmpty) return;
    final ok = await _service.loadDex(path);
    setState(() {
      _status = ok
          ? 'Załadowano klasę dynamicznie z: $path'
          : 'Nie udało się załadować .dex: $path';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Samonaprawa i iniekcja')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Status',
                      style: TextStyle(color: AppColors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(_status, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Wstrzyknięcie skompilowanego .dex (Android)',
            style: TextStyle(color: AppColors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dexPath,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(
              labelText: 'Ścieżka do pliku .dex',
              hintText: '/data/data/com.czarnewilki.prawdy/files/patch.dex',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('Inicjalizuj'),
                  onPressed: _initialized ? null : _init,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Załaduj .dex'),
                  onPressed: _loadDex,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Iniekcja przez plik źródłowy (desktop)',
            style: TextStyle(color: AppColors.white),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.description),
            label: const Text('Wstrzyknij łatkę do źródła'),
            onPressed: () {
              _service.applySourcePatch(
                filePath: 'lib/main.dart',
                marker: '// [SELFHEAL]',
                patch: '// [SELFHEAL] patch applied',
              );
              setState(() {
                _status = 'Łatka źródłowa zgłoszona (desktop).';
              });
            },
          ),
        ],
      ),
    );
  }
}
