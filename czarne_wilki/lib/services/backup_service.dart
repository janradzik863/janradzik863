import 'dart:convert';
import 'dart:io' show Platform;

import '../data/app_database.dart';
import '../data/models.dart';

/// Kopia zapasowa i synchronizacja historii BEZ CHMURY:
/// cały stan aplikacji (rozmowy, profil agenta, modele, preferencje)
/// ląduje w jednym przenośnym pliku JSON, który przenosisz ręcznie
/// między telefonem a desktopem (pendrive, kabel, Messenger do siebie —
/// co wolisz; plik to zwykły tekst, więc nic nie przechodzi przez serwery
/// poza kanałem, który sam wybierzesz).
class BackupService {
  BackupService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;

  static const formatName = 'czarne-wilki-backup';
  static const schemaVersion = 1;

  // ------------------------------------------------------------- eksport

  /// Buduje kompletny plik kopii zapasowej.
  Future<String> create({
    bool includeApiKeys = false,
  }) async {
    final convs = await _db.listConversations();
    final conversations = <Map<String, Object?>>[];
    for (final c in convs) {
      final msgs = await _db.messagesFor(c.id);
      conversations.add({
        'title': c.title,
        'created_at': c.createdAt.millisecondsSinceEpoch,
        'updated_at': c.updatedAt.millisecondsSinceEpoch,
        'hash': _conversationHash(
          c.title,
          c.createdAt.millisecondsSinceEpoch,
          msgs
              .map((m) => (m.role.name, m.content,
                  m.createdAt.millisecondsSinceEpoch))
              .toList(),
        ),
        'messages': [
          for (final m in msgs)
            {
              'role': m.role.name,
              'content': m.content,
              'created_at': m.createdAt.millisecondsSinceEpoch,
              'model_name': m.modelName,
            },
        ],
      });
    }

    final models = await _db.listModels();
    final agentName = await _db.getSetting('agent_name') ?? '';
    final agentRole = await _db.getSetting('agent_role') ?? '';
    final agentSys = await _db.getSetting('agent_system_prompt') ?? '';
    final agentTemp =
        double.tryParse(await _db.getSetting('agent_temp') ?? '') ?? 0.7;

    final backup = {
      'format': formatName,
      'version': schemaVersion,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'device': Platform.operatingSystem,
      'agent': {
        'name': agentName,
        'role': agentRole,
        'system_prompt': agentSys,
        'temperature': agentTemp,
      },
      'preferences': {
        'tts_voice_name': await _db.getSetting('tts_voice_name'),
        'tts_rate': await _db.getSetting('tts_rate'),
        'tts_pitch': await _db.getSetting('tts_pitch'),
      },
      'include_api_keys': includeApiKeys,
      'conversations': conversations,
      'models': [
        for (final m in models)
          {
            'display_name': m.displayName,
            'source': m.source.name,
            // Ścieżki plików GGUF różnią się między urządzeniami —
            // użytkownik wskazuje je ponownie po imporcie.
            'file_path': null,
            'base_url': m.baseUrl,
            'api_key': includeApiKeys ? m.apiKey : null,
            'model_id': m.modelId,
            'chat_format': m.chatFormat,
          },
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  // -------------------------------------------------------------- import

  /// Parsuje i waliduje plik kopii. Zwraca podsumowanie do decyzji
  /// użytkownika (przed faktycznym zapisem).
  Future<BackupSummary> inspect(String json) async {
    final map = jsonDecode(json);
    if (map is! Map<String, dynamic> || map['format'] != formatName) {
      throw const BackupException('To nie jest plik kopii Czarne Wilki.');
    }
    if ((map['version'] as num?)?.toInt() != schemaVersion) {
      throw const BackupException(
          'Nieobsługiwana wersja formatu kopii — zaktualizuj aplikację.');
    }

    final incoming = (map['conversations'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    // Hashe istniejących rozmów → pomijanie duplikatów.
    final existing = <String>{};
    for (final c in await _db.listConversations()) {
      final msgs = await _db.messagesFor(c.id);
      existing.add(_conversationHash(
        c.title,
        c.createdAt.millisecondsSinceEpoch,
        msgs
            .map((m) =>
                (m.role.name, m.content, m.createdAt.millisecondsSinceEpoch))
            .toList(),
      ));
    }

    var newCount = 0;
    for (final c in incoming) {
      final h = (c['hash'] as String?) ??
          _conversationHash(
            c['title'] as String? ?? '',
            (c['created_at'] as num?)?.toInt() ?? 0,
            _messageTuples(c),
          );
      if (!existing.contains(h)) newCount++;
    }

    final agent = map['agent'] as Map<String, dynamic>?;
    return BackupSummary(
      raw: map,
      totalConversations: incoming.length,
      newConversations: newCount,
      duplicates: incoming.length - newCount,
      modelCount: (map['models'] as List? ?? const []).length,
      hasAgentProfile:
          agent != null && ((agent['name'] as String?) ?? '').isNotEmpty,
      hasApiKeys: (map['include_api_keys'] as bool? ?? false) &&
          (map['models'] as List? ?? const [])
              .any((m) => (m as Map)['api_key'] != null),
    );
  }

  /// Wykonuje import po decyzji użytkownika.
  Future<RestoreResult> restore(
    BackupSummary summary, {
    bool conversations = true,
    bool models = true,
    bool agentProfile = true,
  }) async {
    var importedConv = 0;
    var importedModels = 0;
    var skipped = 0;

    if (conversations) {
      final existing = <String>{};
      for (final c in await _db.listConversations()) {
        final msgs = await _db.messagesFor(c.id);
        existing.add(_conversationHash(
          c.title,
          c.createdAt.millisecondsSinceEpoch,
          msgs
              .map((m) =>
                  (m.role.name, m.content, m.createdAt.millisecondsSinceEpoch))
              .toList(),
        ));
      }

      for (final c in (summary.raw['conversations'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) {
        final h = (c['hash'] as String?) ??
            _conversationHash(
              c['title'] as String? ?? '',
              (c['created_at'] as num?)?.toInt() ?? 0,
              _messageTuples(c),
            );
        if (existing.contains(h)) {
          skipped++;
          continue;
        }
        final conv = await _db.createConversation(
            (c['title'] as String?) ?? 'Import');
        for (final m in (c['messages'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
          await _db.addMessage(Message(
            id: 0,
            conversationId: conv.id,
            role: Role.values.firstWhere(
              (r) => r.name == (m['role'] as String? ?? 'user'),
              orElse: () => Role.user,
            ),
            content: m['content'] as String? ?? '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(
                (m['created_at'] as num?)?.toInt() ??
                    DateTime.now().millisecondsSinceEpoch),
            modelName: m['model_name'] as String?,
          ));
        }
        existing.add(h);
        importedConv++;
      }
    }

    if (models) {
      final current = await _db.listModels();
      for (final m in (summary.raw['models'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) {
        final modelId = m['model_id'] as String?;
        final dup = current.any((c) =>
            c.displayName == (m['display_name'] as String? ?? '') ||
            (modelId != null && c.modelId == modelId));
        if (dup) {
          skipped++;
          continue;
        }
        await _db.addModel(ModelEntry(
          id: 0,
          displayName: (m['display_name'] as String?) ?? 'model',
          source: m['source'] == 'cloud'
              ? ModelSource.cloud
              : ModelSource.local,
          filePath: m['file_path'] as String?,
          baseUrl: m['base_url'] as String?,
          apiKey: m['api_key'] as String?,
          modelId: modelId,
          chatFormat: (m['chat_format'] as String?) ?? 'chatml',
        ));
        importedModels++;
      }
    }

    if (agentProfile) {
      final agent = summary.raw['agent'] as Map<String, dynamic>?;
      if (agent != null) {
        await _db.setSetting('agent_name', (agent['name'] as String?) ?? '');
        await _db.setSetting('agent_role', (agent['role'] as String?) ?? '');
        await _db.setSetting(
            'agent_system_prompt', (agent['system_prompt'] as String?) ?? '');
        await _db.setSetting('agent_temp',
            ((agent['temperature'] as num?) ?? 0.7).toString());
      }
    }

    final prefs = summary.raw['preferences'] as Map<String, dynamic>?;
    if (prefs != null) {
      final voice = prefs['tts_voice_name'] as String?;
      if (voice != null && voice.isNotEmpty) {
        await _db.setSetting('tts_voice_name', voice);
      }
    }

    return RestoreResult(
      importedConversations: importedConv,
      importedModels: importedModels,
      skippedDuplicates: skipped,
    );
  }

  // ------------------------------------------------------------- hashe

  static List<(String, String, int)> _messageTuples(Map<String, dynamic> c) =>
      [
        for (final m in (c['messages'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          (
            m['role'] as String? ?? '',
            m['content'] as String? ?? '',
            (m['created_at'] as num?)?.toInt() ?? 0,
          ),
      ];

  /// Deterministyczny hash (djb2) — stabilny między platformami,
  /// bez zewnętrznych zależności.
  static String _conversationHash(
      String title, int createdAt, List<(String, String, int)> messages) {
    final b = StringBuffer()
      ..write(title)
      ..write('|')
      ..write(createdAt)
      ..write('|');
    for (final m in messages) {
      b..write(m.$1)..write('\u0001')..write(m.$2)..write('\u0001')
        ..write(m.$3)..write('\u0002');
    }
    var h = 5381;
    for (final code in b.toString().codeUnits) {
      h = (((h << 5) + h) ^ code) & 0x7FFFFFFF;
    }
    return h.toRadixString(16);
  }
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupSummary {
  BackupSummary({
    required this.raw,
    required this.totalConversations,
    required this.newConversations,
    required this.duplicates,
    required this.modelCount,
    required this.hasAgentProfile,
    required this.hasApiKeys,
  });

  final Map<String, dynamic> raw;
  final int totalConversations;
  final int newConversations;
  final int duplicates;
  final int modelCount;
  final bool hasAgentProfile;
  final bool hasApiKeys;
}

class RestoreResult {
  RestoreResult({
    required this.importedConversations,
    required this.importedModels,
    required this.skippedDuplicates,
  });

  final int importedConversations;
  final int importedModels;
  final int skippedDuplicates;
}
