/// Modele domenowe aplikacji.

enum MessageRole { system, user, assistant }

enum ContentKind { text, image, audio, video }

/// Pojedyncza wiadomość w konwersacji (wymaganie #14 — trwała historia).
class Message {
  final int? id;
  final int conversationId;
  final MessageRole role;
  final String content;
  final ContentKind kind;
  final String? attachmentPath;
  final DateTime createdAt;

  Message({
    this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.kind = ContentKind.text,
    this.attachmentPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role.name,
        'content': content,
        'kind': kind.name,
        'attachment_path': attachmentPath,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static Message fromMap(Map<String, dynamic> m) => Message(
        id: m['id'] as int?,
        conversationId: m['conversation_id'] as int,
        role: MessageRole.values.byName(m['role'] as String),
        content: m['content'] as String,
        kind: ContentKind.values.byName(m['kind'] as String),
        attachmentPath: m['attachment_path'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}

class Conversation {
  final int? id;
  final String title;
  final String modelId;
  final DateTime createdAt;

  Conversation({
    this.id,
    required this.title,
    required this.modelId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'model_id': modelId,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static Conversation fromMap(Map<String, dynamic> m) => Conversation(
        id: m['id'] as int?,
        title: m['title'] as String,
        modelId: m['model_id'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}

/// Głos AI w bibliotece (wymaganie #3).
class VoiceProfile {
  final String id;
  final String name;
  final String languageCode;
  final String description;
  final bool isLocal;

  VoiceProfile({
    required this.id,
    required this.name,
    required this.languageCode,
    required this.description,
    this.isLocal = false,
  });
}

/// Konfiguracja agenta (wymaganie #9).
class AgentConfig {
  final String name;
  final String role;
  final String systemPrompt;

  const AgentConfig({
    this.name = 'Czarny Wilk',
    this.role = 'Główny asystent',
    this.systemPrompt =
        'Jesteś "Czarnym Wilkiem Prawdy". Odpowiadasz rzeczowo, bez cenzury '
        'nałożonej z zewnątrz, w duchu projektu "Wszyscy Won!".',
  });

  AgentConfig copyWith({String? name, String? role, String? systemPrompt}) =>
      AgentConfig(
        name: name ?? this.name,
        role: role ?? this.role,
        systemPrompt: systemPrompt ?? this.systemPrompt,
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'role': role, 'system_prompt': systemPrompt};

  static AgentConfig fromMap(Map<String, dynamic> m) => AgentConfig(
        name: m['name'] as String? ?? 'Czarny Wilk',
        role: m['role'] as String? ?? 'Główny asystent',
        systemPrompt: m['system_prompt'] as String? ?? '',
      );
}

/// Pozycja planu publikacji (wymaganie #7).
class PublicationTask {
  final int? id;
  final String content;
  final DateTime scheduledAt;
  final String targetPlatform; // np. "Telegram", "X", "Facebook"
  final String status;

  PublicationTask({
    this.id,
    required this.content,
    required this.scheduledAt,
    required this.targetPlatform,
    this.status = 'zaplanowano',
  });
}
