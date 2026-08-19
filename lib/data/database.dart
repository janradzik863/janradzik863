import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'models.dart';

/// Lokalna baza danych SQLite — trwała historia konwersacji (wymaganie #14)
/// oraz plan publikacji (wymaganie #7). Dane nigdy nie opuszczają urządzenia.
class AppDatabase {
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    await open();
    return _db!;
  }

  Future<void> open() async {
    if (_db != null) return;
    final dir = await _dataDir();
    final path = p.join(dir, 'czarne_wilki.db');
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      _db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
      );
    } else {
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
      );
    }
  }

  Future<String> _dataDir() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    }
    return (await getDatabasesPath());
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        model_id TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        kind TEXT NOT NULL,
        attachment_path TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE publication_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        scheduled_at INTEGER NOT NULL,
        target_platform TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
  }

  // --- Konwersacje ---

  Future<int> createConversation(String title, String modelId) async {
    final d = await db;
    return d.insert('conversations', {
      'title': title,
      'model_id': modelId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Conversation>> conversations() async {
    final d = await db;
    final rows = await d.query('conversations', orderBy: 'created_at DESC');
    return rows.map(Conversation.fromMap).toList();
  }

  // --- Wiadomości ---

  Future<int> insertMessage(Message m) async {
    final d = await db;
    return d.insert('messages', m.toMap());
  }

  Future<List<Message>> messagesFor(int conversationId) async {
    final d = await db;
    final rows = await d.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Message.fromMap).toList();
  }

  Future<void> clearMessages(int conversationId) async {
    final d = await db;
    await d.delete('messages',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
  }
}
