import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../engine/engine_manager.dart';
import '../../engine/hf_repository.dart';
import '../../engine/local_engine.dart';

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  final _search = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  List<HfModel> _results = [];
  bool _searching = false;
  bool _libReady = false;
  String? _downloadLabel;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final ready = await EngineManager().localReady();
      if (mounted) setState(() => _libReady = ready);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _baseCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engines = context.watch<EngineManager>();
    final db = context.read<AppDatabase>();
    final hf = context.read<HfRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modele'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: CwFlagStrip(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tryb pracy
          Card(
            child: SwitchListTile(
              title: const Text('Tryb Sieciowy',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                engines.online
                    ? 'Dozwolone połączenia: chmura i pobieranie modeli.'
                    : 'OFFLINE — zero połączeń. Działa tylko model lokalny.',
                style: const TextStyle(fontSize: 12, color: CwColors.whiteDim),
              ),
              value: engines.online,
              activeColor: CwColors.crimson,
              onChanged: (v) => engines.setOnline(v),
            ),
          ),
          const SizedBox(height: 18),

          _SectionHeader(
              icon: Icons.smartphone, title: 'MODELE LOKALNE (GGUF)'),
          const SizedBox(height: 8),
          _LibStatusCard(ready: _libReady),
          const SizedBox(height: 10),
          FutureBuilder<List<ModelEntry>>(
            future: db.listModels(),
            builder: (context, snap) {
              final locals = (snap.data ?? const [])
                  .where((m) => m.source == ModelSource.local)
                  .toList();
              if (locals.isEmpty) {
                return const _InfoCard(
                    'Brak lokalnych modeli. Wyszukaj i pobierz plik GGUF '
                    'poniżej — model będzie działał w 100% na urządzeniu.');
              }
              return Column(
                children: [
                  for (final m in locals)
                    _ModelTile(
                      title: m.displayName,
                      active: engines.activeModel?.id == m.id,
                      onTap: () async {
                        await engines.activate(m);
                        if (context.mounted) setState(() {});
                      },
                      onDelete: () async {
                        await db.deleteModel(m.id);
                        if (context.mounted) setState(() {});
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _HfSearch(
            controller: _search,
            searching: _searching,
            onSearch: () => _doSearch(hf),
            results: _results,
            downloadLabel: _downloadLabel,
            downloadProgress: _downloadProgress,
            enabled: engines.online,
            onPickFile: (repoId, file) => _download(hf, repoId, file),
          ),
          const SizedBox(height: 22),

          _SectionHeader(
              icon: Icons.cloud_outlined, title: 'MODELE CHMUROWE (API)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _PresetChip(
                  label: 'OpenRouter (darmowe)',
                  onTap: () => _applyPreset(
                      'https://openrouter.ai/api/v1', 'openai/gpt-oss-120b:free')),
              _PresetChip(
                  label: 'DeepSeek',
                  onTap: () => _applyPreset(
                      'https://api.deepseek.com/v1', 'deepseek-chat')),
              _PresetChip(
                  label: 'OpenAI',
                  onTap: () =>
                      _applyPreset('https://api.openai.com/v1', 'gpt-4o-mini')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseCtrl,
            decoration: const InputDecoration(labelText: 'Base URL'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Klucz API'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _modelCtrl,
            decoration:
                const InputDecoration(labelText: 'Nazwa modelu (model id)'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _saveCloudModel(db, engines),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Zapisz i aktywuj model chmurowy'),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ModelEntry>>(
            future: db.listModels(),
            builder: (context, snap) {
              final clouds = (snap.data ?? const [])
                  .where((m) => m.source == ModelSource.cloud)
                  .toList();
              if (clouds.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  for (final m in clouds)
                    _ModelTile(
                      title: '${m.displayName} (${m.modelId ?? '?'})',
                      active: engines.activeModel?.id == m.id,
                      onTap: () async {
                        await engines.activate(m);
                        if (context.mounted) setState(() {});
                      },
                      onDelete: () async {
                        await db.deleteModel(m.id);
                        if (context.mounted) setState(() {});
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _applyPreset(String base, String model) {
    _baseCtrl.text = base;
    _modelCtrl.text = model;
  }

  Future<void> _doSearch(HfRepository hf) async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      _results = await hf.search(q);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Wyszukiwanie nie powiodło się: $e')));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _download(
      HfRepository hf, String repoId, String file) async {
    setState(() {
      _downloadLabel = '$repoId → ${file.split('/').last}';
      _downloadProgress = 0;
    });
    try {
      final path = await hf.download(
        repoId: repoId,
        filePath: file,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      final db = context.read<AppDatabase>();
      final engines = context.read<EngineManager>();
      final entry = await db.addModel(ModelEntry(
        id: 0,
        displayName: file.split('/').last,
        source: ModelSource.local,
        filePath: path,
        chatFormat: _guessFormat(file),
      ));
      await engines.activate(entry);
      if (mounted) {
        setState(() => _downloadLabel = null);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model pobrany i aktywny.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadLabel = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Pobieranie przerwane: $e')));
      }
    }
  }

  static String _guessFormat(String fileName) {
    final n = fileName.toLowerCase();
    if (n.contains('gemma')) return 'gemma';
    if (n.contains('llama-2') || n.contains('llama2')) return 'llama2';
    if (n.contains('mistral') || n.contains('mixtral')) return 'mistral';
    return 'chatml';
  }

  Future<void> _saveCloudModel(AppDatabase db, EngineManager engines) async {
    final base = _baseCtrl.text.trim();
    final key = _keyCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    if (base.isEmpty || key.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Uzupełnij Base URL, klucz API i nazwę modelu.')));
      return;
    }
    final entry = await db.addModel(ModelEntry(
      id: 0,
      displayName: model.split('/').last,
      source: ModelSource.cloud,
      baseUrl: base,
      apiKey: key,
      modelId: model,
    ));
    await engines.activate(entry);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Model chmurowy aktywny.')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CwColors.crimson),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: CwColors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _LibStatusCard extends StatelessWidget {
  const _LibStatusCard({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              ready ? Icons.check_circle : Icons.info_outline,
              color: ready ? CwColors.online : CwColors.offline,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ready
                    ? 'Biblioteka llama.cpp obecna — lokalne modele gotowe.'
                    : 'Biblioteka libllama.so nie została jeszcze dołączona '
                        '(uruchom tools/build_llama_android.sh przed budową '
                        'APK). Do tego czasu działają modele chmurowe.',
                style: const TextStyle(fontSize: 12, color: CwColors.whiteDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: CwColors.whiteDim)),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.title,
    required this.active,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: active ? CwColors.crimsonDark : CwColors.surface,
      child: ListTile(
        title: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        leading: Icon(
          active ? Icons.radio_button_checked : Icons.radio_button_off,
          color: active ? CwColors.white : CwColors.whiteDim,
          size: 20,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      backgroundColor: CwColors.surfaceAlt,
      side: const BorderSide(color: CwColors.crimson),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }
}

class _HfSearch extends StatelessWidget {
  const _HfSearch({
    required this.controller,
    required this.searching,
    required this.onSearch,
    required this.results,
    required this.downloadLabel,
    required this.downloadProgress,
    required this.enabled,
    required this.onPickFile,
  });

  final TextEditingController controller;
  final bool searching;
  final VoidCallback onSearch;
  final List<HfModel> results;
  final String? downloadLabel;
  final double downloadProgress;
  final bool enabled;
  final void Function(String repoId, String file) onPickFile;

  @override
  Widget build(BuildContext context) {
    final hf = context.read<HfRepository>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pobierz z Hugging Face',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled,
                    decoration: const InputDecoration(
                        hintText: 'np. llama 3.2 1b instruct gguf'),
                    onSubmitted: (_) => onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: enabled && !searching ? onSearch : null,
                  icon: searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                ),
              ],
            ),
            if (!enabled)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Pobieranie wymaga trybu Sieciowego.',
                  style: TextStyle(fontSize: 11, color: CwColors.offline),
                ),
              ),
            for (final r in results.take(8))
              FutureBuilder<List<String>>(
                future: hf.listGgufFiles(r.repoId),
                builder: (context, snap) {
                  final files = snap.data ?? const <String>[];
                  return ExpansionTile(
                    dense: true,
                    iconColor: CwColors.crimson,
                    title: Text(r.repoId,
                        style: const TextStyle(fontSize: 12.5)),
                    subtitle: Text(
                        'pobrania: ${r.downloads} • plików GGUF: '
                        '${snap.connectionState == ConnectionState.waiting ? '…' : files.length}',
                        style:
                            const TextStyle(fontSize: 10.5, color: CwColors.whiteDim)),
                    children: [
                      for (final f in files.take(6))
                        ListTile(
                          dense: true,
                          title: Text(f.split('/').last,
                              style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.download, size: 18),
                          onTap: () => onPickFile(r.repoId, f),
                        ),
                    ],
                  );
                },
              ),
            if (downloadLabel != null) ...[
              const SizedBox(height: 8),
              Text(downloadLabel!,
                  style:
                      const TextStyle(fontSize: 11, color: CwColors.whiteDim)),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: downloadProgress,
                color: CwColors.crimson,
                backgroundColor: CwColors.surfaceAlt,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        context.read<HfRepository>().cancelAll(),
                    child: const Text('Anuluj pobieranie'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
