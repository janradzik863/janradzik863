/// Modele danych aplikacji Czarne Wilki.

enum Role { system, user, assistant }

class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.modelName,
    this.attachmentPath,
  });

  final int id;
  final int conversationId;
  final Role role;
  final String content;
  final DateTime createdAt;

  /// Nazwa modelu, który wygenerował odpowiedź (historia wspólna
  /// dla wszystkich modeli — dzięki temu nowy model zna kontekst).
  final String? modelName;

  /// Opcjonalny załącznik (np. wygenerowany obraz).
  final String? attachmentPath;

  Map<String, Object?> toRow() => {
        'conversation_id': conversationId,
        'role': role.name,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
        'model_name': modelName,
        'attachment_path': attachmentPath,
      };

  static Message fromRow(Map<String, Object?> row) => Message(
        id: row['id'] as int,
        conversationId: row['conversation_id'] as int,
        role: Role.values.firstWhere((r) => r.name == row['role']),
        content: row['content'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        modelName: row['model_name'] as String?,
        attachmentPath: row['attachment_path'] as String?,
      );
}

class Conversation {
  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toRow() => {
        'title': title,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };
}

/// Profil agenta (personalizacja): imię, rola i instrukcja systemowa.
class AgentProfile {
  AgentProfile({
    required this.name,
    required this.role,
    required this.systemPrompt,
    this.temperature = 0.7,
  });

  final String name;
  final String role;
  final String systemPrompt;
  final double temperature;

  /// Pełny prompt systemowy składany z roli i instrukcji własnych.
  String get effectiveSystemPrompt {
    final buffer = StringBuffer();
    if (name.trim().isNotEmpty) {
      buffer.write('Nazywasz się ${name.trim()}. ');
    }
    if (role.trim().isNotEmpty) {
      buffer.write('Twoja rola: ${role.trim()}. ');
    }
    if (systemPrompt.trim().isNotEmpty) {
      buffer.write('\n${systemPrompt.trim()}');
    }
    return buffer.toString().trim();
  }

  AgentProfile copyWith({
    String? name,
    String? role,
    String? systemPrompt,
    double? temperature,
  }) =>
      AgentProfile(
        name: name ?? this.name,
        role: role ?? this.role,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        temperature: temperature ?? this.temperature,
      );
}

/// Źródło modelu: lokalny GGUF albo dostawca chmurowy.
enum ModelSource { local, cloud }

class ModelEntry {
  ModelEntry({
    required this.id,
    required this.displayName,
    required this.source,
    this.filePath,
    this.baseUrl,
    this.apiKey,
    this.modelId,
    this.chatFormat = 'chatml',
    this.active = false,
  });

  final int id;
  final String displayName;
  final ModelSource source;

  /// Dla modeli lokalnych: ścieżka do pliku .gguf na urządzeniu.
  final String? filePath;

  /// Dla modeli chmurowych: konfiguracja zgodna z OpenAI (OpenRouter/DeepSeek).
  final String? baseUrl;
  final String? apiKey;
  final String? modelId;

  /// Format czatu dla modeli lokalnych (chatml / llama2 / gemma / mistral).
  final String chatFormat;

  /// Czy model jest aktualnie wybrany.
  final bool active;

  Map<String, Object?> toRow() => {
        'display_name': displayName,
        'source': source.name,
        'file_path': filePath,
        'base_url': baseUrl,
        'api_key': apiKey,
        'model_id': modelId,
        'chat_format': chatFormat,
        'active': active ? 1 : 0,
      };

  static ModelEntry fromRow(Map<String, Object?> row) => ModelEntry(
        id: row['id'] as int,
        displayName: row['display_name'] as String,
        source: ModelSource.values.firstWhere((s) => s.name == row['source']),
        filePath: row['file_path'] as String?,
        baseUrl: row['base_url'] as String?,
        apiKey: row['api_key'] as String?,
        modelId: row['model_id'] as String?,
        chatFormat: (row['chat_format'] as String?) ?? 'chatml',
        active: (row['active'] as int? ?? 0) == 1,
      );
}

/// Pojedynczy głos TTS dostępny na urządzeniu.
class TtsVoice {
  TtsVoice({
    required this.name,
    required this.locale,
    required this.isDefault,
  });

  final String name;
  final String locale;
  final bool isDefault;

  bool get isPolish => locale.toLowerCase().startsWith('pl');
}
