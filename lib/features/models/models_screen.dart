import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/local_inference_service.dart';
import '../../services/model_repository.dart';

/// Zarządzanie lokalnymi modelami GGUF (wymaganie #4).
///
/// - lista zainstalowanych modeli,
/// - pobieranie z zewnętrznych repozytoriów (Hugging Face / dowolny URL)
///   z paskiem postępu,
/// - ładowanie do natywnego silnika llama.cpp (tryb offline, #19).
class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  final _repo = ModelRepository();
  final _engine = LocalInferenceService();

  final _url = TextEditingController();
  final _name = TextEditingController();

  List<String> _installed = [];
  bool _loading = true;
  double _progress = 0;
  bool _downloading = false;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await _repo.installedModels();
    if (mounted) {
      setState(() {
        _installed = list;
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    final url = _url.text.trim();
    final name = _name.text.trim();
    if (url.isEmpty || name.isEmpty) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      final path = await _repo.download(
        url: url,
        fileName: name,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pobrano: $path')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd pobierania: $e')),
      );
    } finally {
      setState(() => _downloading = false);
      _refresh();
    }
  }

  Future<void> _load(String path) async {
    try {
      await _engine.loadModel(path: path, contextSize: 2048, gpuLayers: -1);
      setState(() => _loadedPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Załadowano model (tryb offline gotowy)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się załadować modelu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modele lokalne (GGUF)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Zainstalowane modele',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_installed.isEmpty)
            const Text('Brak modeli. Pobierz poniżej.',
                style: TextStyle(color: Colors.grey))
          else
            for (final path in _installed)
              Card(
                color: AppColors.surface,
                child: ListTile(
                  leading: const Icon(Icons.memory, color: AppColors.red),
                  title: Text(
                    path.split('/').last,
                    style: const TextStyle(color: AppColors.white),
                  ),
                  subtitle: Text(
                    _loadedPath == path ? 'Załadowany' : 'Na urządzeniu',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: _loadedPath == path
                      ? const Icon(Icons.check_circle, color: AppColors.red)
                      : ElevatedButton(
                          onPressed: () => _load(path),
                          child: const Text('Załaduj'),
                        ),
                ),
              ),
          const Divider(height: 32, color: AppColors.surface),
          const Text('Pobierz z repozytorium (Hugging Face / URL)',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(
              labelText: 'URL pliku .gguf',
              hintText:
                  'https://huggingface.co/.../qwen2.5-1.5b-instruct-q4_k_m.gguf',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            style: const TextStyle(color: AppColors.white),
            decoration: const InputDecoration(
              labelText: 'Nazwa pliku',
              hintText: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
            ),
          ),
          const SizedBox(height: 12),
          if (_downloading) ...[
            LinearProgressIndicator(
              value: _progress,
              color: AppColors.red,
              backgroundColor: AppColors.surface,
            ),
            const SizedBox(height: 8),
            Text('${(_progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.grey)),
          ],
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Pobierz model'),
            onPressed: _downloading ? null : _download,
          ),
          const SizedBox(height: 12),
          const Text(
            'Modele są pobierane i uruchamiane w 100% na urządzeniu '
            '(llama.cpp, GPU/Vulkan). Po pobraniu nie jest wymagany internet (#4, #19).',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
