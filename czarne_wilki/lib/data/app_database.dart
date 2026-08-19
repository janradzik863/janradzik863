import 'dart:io' show Directory, Platform;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sffi;

import 'models.dart';

/// Lokalna baza SQLite aplikacji — cała historia konwersacji, modele
/// i ustawienia żyją wyłącznie na urządzeniu użytkownika.
///
/// Android/iOS: sqflite (kanał platformowy).
/// Linux/Windows: sqflite_common_ffi (bundlowany silnik sqlite3).
class AppDatabase {
  AppDatabase._();

  static const _dbName = 'czarne_wilki.db';
  static const _dbVersion = 1;

  static Database? _db;
  static bool _ffiInitialized = false;

  static Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  /// Ścieżka pliku bazy. Na desktopie getDatabasesPath() z sqflite ma
  /// szczątkową implementację — zgodnie z dokumentacją sqflite_common_ffi
  /// używamy własnej lokalizacji przez path_provider.
  static Future<String> _dbPath() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return p.join(await getDatabasesPath(), _dbName);
    }
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory('${dir.path}/database');
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    return p.join(dbDir.path, _dbName);
  }

  static Future<Database> _open() async {
    // Desktop: silnik FFI z bundlowanym sqlite3.
    if (!Platform.isAndroid && !Platform.isIOS && !_ffiInitialized) {
      sffi.sqfliteFfiInit();
      databaseFactory = sffi.databaseFactoryFfi;
      _ffiInitialized = true;
    }
    return openDatabase(
      await _dbPath(),
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            model_name TEXT,
            attachment_path TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_messages_conversation
          ON messages(conversation_id, created_at)
        ''');
        await db.execute('''
          CREATE TABLE models (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            display_name TEXT NOT NULL,
            source TEXT NOT NULL,
            file_path TEXT,
            base_url TEXT,
            api_key TEXT,
            model_id TEXT,
            chat_format TEXT NOT NULL DEFAULT 'chatml',
            active INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------- settings

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ----------------------------------------------------------- conversations

  Future<Conversation> createConversation(String title) async {
    final db = await database;
    final now = DateTime.now();
    final id = await db.insert('conversations',
        Conversation(id: 0, title: title, createdAt: now, updatedAt: now)
            .toRow());
    return Conversation(id: id, title: title, createdAt: now, updatedAt: now);
  }

  Future<List<Conversation>> listConversations() async {
    final db = await database;
    final rows =
        await db.query('conversations', orderBy: 'updated_at DESC', limit: 50);
    return rows
        .map((r) => Conversation(
              id: r['id'] as int,
              title: r['title'] as String,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['created_at'] as int),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  r['updated_at'] as int),
            ))
        .toList();
  }

  Future<void> touchConversation(int id) async {
    final db = await database;
    await db.update('conversations', {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteConversation(int id) async {
    final db = await database;
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [id]);
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------- messages

  Future<Message> addMessage(Message msg) async {
    final db = await database;
    final id = await db.insert('messages', msg.toRow());
    await touchConversation(msg.conversationId);
    return Message(
      id: id,
      conversationId: msg.conversationId,
      role: msg.role,
      content: msg.content,
      createdAt: msg.createdAt,
      modelName: msg.modelName,
      attachmentPath: msg.attachmentPath,
    );
  }

  /// Pełna historia rozmowy — dostępna dla KAŻDEGO modelu, który ją
  /// otworzy (zmiana modelu nie tracі kontekstu).
  Future<List<Message>> messagesFor(int conversationId) async {
    final db = await database;
    final rows = await db.query('messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC, id ASC');
    return rows.map(Message.fromRow).toList();
  }

  // ------------------------------------------------------------------ models

  Future<List<ModelEntry>> listModels() async {
    final db = await database;
    final rows = await db.query('models', orderBy: 'id ASC');
    return rows.map(ModelEntry.fromRow).toList();
  }

  Future<ModelEntry> addModel(ModelEntry m) async {
    final db = await database;
    final id = await db.insert('models', m.toRow());
    return ModelEntry(
      id: id,
      displayName: m.displayName,
      source: m.source,
      filePath: m.filePath,
      baseUrl: m.baseUrl,
      apiKey: m.apiKey,
      modelId: m.modelId,
      chatFormat: m.chatFormat,
      active: m.active,
    );
  }

  Future<void> updateModel(ModelEntry m) async {
    final db = await database;
    await db.update('models', m.toRow(), where: 'id = ?', whereArgs: [m.id]);
  }

  /// Ustawia dokładnie jeden aktywny model.
  Future<void> activateModel(int id) async {
    final db = await database;
    await db.update('models', {'active': 0});
    await db.update('models', {'active': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<ModelEntry?> activeModel() async {
    final db = await database;
    final rows = await db.query('models', where: 'active = 1', limit: 1);
    if (rows.isEmpty) return null;
    return ModelEntry.fromRow(rows.first);
  }

  Future<void> deleteModel(int id) async {
    final db = await database;
    await db.delete('models', where: 'id = ?', whereArgs: [id]);
  }
}
