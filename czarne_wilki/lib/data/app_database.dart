import 'dart:io' show Directory, Platform;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sffi;

import 'models.dart';

/// Lokalna baza SQLite aplikacji — cała historia konwersacji, modele,
/// ustawienia, planer publikacji, komunikator, role RBAC, kolejka moderacji,
/// ogłoszenia, wpłaty — wszystko żyje wyłącznie na urządzeniu użytkownika.
///
/// Android/iOS: sqflite (kanał platformowy).
/// Linux/Windows: sqflite_common_ffi (bundlowany silnik sqlite3).
class AppDatabase {
  AppDatabase._();

  /// Singleton factory. Każde `AppDatabase()` zwraca ten sam obiekt.
  static final AppDatabase _instance = AppDatabase._();
  factory AppDatabase() => _instance;

  static const _dbName = 'czarne_wilki.db';
  static const _dbVersion = 2;

  static Database? _db;
  static bool _ffiInitialized = false;

  static Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

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
    if (!Platform.isAndroid && !Platform.isIOS && !_ffiInitialized) {
      sffi.sqfliteFfiInit();
      databaseFactory = sffi.databaseFactoryFfi;
      _ffiInitialized = true;
    }
    return openDatabase(
      await _dbPath(),
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
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
        attachment_path TEXT,
        attachment_type TEXT
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
        active INTEGER NOT NULL DEFAULT 0,
        unfiltered INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    // ---- Planer Publikacji (Pkt 7) ----
    await db.execute('''
      CREATE TABLE planner_posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        platform TEXT NOT NULL,
        scheduled_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        created_at INTEGER NOT NULL,
        approved INTEGER NOT NULL DEFAULT 0,
        attachment_path TEXT
      )
    ''');
    // ---- Komunikator E2E (Pkt 12) ----
    await db.execute('''
      CREATE TABLE messenger_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        display_name TEXT NOT NULL,
        public_key TEXT NOT NULL,
        device_id TEXT NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE messenger_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id INTEGER NOT NULL REFERENCES messenger_contacts(id) ON DELETE CASCADE,
        direction TEXT NOT NULL,
        encrypted_content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        read INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // ---- Radio Społecznościowe (Pkt 13) ----
    await db.execute('''
      CREATE TABLE radio_tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        artist TEXT NOT NULL DEFAULT '',
        file_path TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        added_by TEXT NOT NULL DEFAULT 'local',
        added_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE radio_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_id INTEGER NOT NULL REFERENCES radio_tracks(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        added_at INTEGER NOT NULL
      )
    ''');
    // ---- RBAC / Role (Pkt 15) ----
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'user',
        created_at INTEGER NOT NULL
      )
    ''');
    // ---- Moderacja (Pkt 16) ----
    await db.execute('''
      CREATE TABLE moderation_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content_type TEXT NOT NULL,
        content TEXT NOT NULL,
        source_id INTEGER,
        submitted_by TEXT NOT NULL DEFAULT 'agent',
        status TEXT NOT NULL DEFAULT 'pending',
        reviewed_at INTEGER,
        reviewer TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    // ---- Ogłoszenia / Alerty (Pkt 17) ----
    await db.execute('''
      CREATE TABLE announcements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'normal',
        created_at INTEGER NOT NULL,
        read INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // ---- Wpłaty / Wsparcie (Pkt 21) ----
    await db.execute('''
      CREATE TABLE donations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        donor_name TEXT NOT NULL DEFAULT 'Anonimowy Wilk',
        amount_pln REAL NOT NULL,
        message TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    // ---- Agent komentarzy (Pkt 18) - logi ----
    await db.execute('''
      CREATE TABLE comment_agent_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL,
        platform TEXT NOT NULL,
        comment_text TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL
      )
    ''');
    // ---- Asystent Kodowania - snippety (Pkt 10) ----
    await db.execute('''
      CREATE TABLE code_snippets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        language TEXT NOT NULL DEFAULT 'dart',
        code TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      // Migration from v1 to v2: add new tables
      await _onCreate(db, newV);
    }
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
    await db.update('conversations',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
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
      attachmentType: msg.attachmentType,
    );
  }

  /// Pełna historia rozmowy — dostępna dla KAŻDEGO modelu, który ją
  /// otworzy (zmiana modelu nie traci kontekstu).
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
      unfiltered: m.unfiltered,
    );
  }

  Future<void> updateModel(ModelEntry m) async {
    final db = await database;
    await db.update('models', m.toRow(), where: 'id = ?', whereArgs: [m.id]);
  }

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

  // ---------------------------------------------------------- planner posts

  Future<PlannerPost> addPlannerPost(PlannerPost post) async {
    final db = await database;
    final id = await db.insert('planner_posts', post.toRow());
    return post.copyWith(id: id);
  }

  Future<List<PlannerPost>> listPlannerPosts() async {
    final db = await database;
    final rows = await db.query('planner_posts', orderBy: 'scheduled_at ASC');
    return rows.map(PlannerPost.fromRow).toList();
  }

  Future<void> updatePlannerPost(PlannerPost post) async {
    final db = await database;
    await db.update('planner_posts', post.toRow(),
        where: 'id = ?', whereArgs: [post.id]);
  }

  Future<void> deletePlannerPost(int id) async {
    final db = await database;
    await db.delete('planner_posts', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------- moderation queue

  Future<ModerationItem> addModerationItem(ModerationItem item) async {
    final db = await database;
    final id = await db.insert('moderation_queue', item.toRow());
    return item.copyWith(id: id);
  }

  Future<List<ModerationItem>> listModerationQueue({String? status}) async {
    final db = await database;
    final rows = await db.query('moderation_queue',
        where: status != null ? 'status = ?' : null,
        whereArgs: status != null ? [status] : null,
        orderBy: 'created_at DESC');
    return rows.map(ModerationItem.fromRow).toList();
  }

  Future<void> updateModerationItem(ModerationItem item) async {
    final db = await database;
    await db.update('moderation_queue', item.toRow(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  // ---------------------------------------------------------- announcements

  Future<Announcement> addAnnouncement(Announcement a) async {
    final db = await database;
    final id = await db.insert('announcements', a.toRow());
    return a.copyWith(id: id);
  }

  Future<List<Announcement>> listAnnouncements() async {
    final db = await database;
    final rows =
        await db.query('announcements', orderBy: 'created_at DESC', limit: 100);
    return rows.map(Announcement.fromRow).toList();
  }

  Future<void> markAnnouncementRead(int id) async {
    final db = await database;
    await db.update('announcements', {'read': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // --------------------------------------------------------------- donations

  Future<Donation> addDonation(Donation d) async {
    final db = await database;
    final id = await db.insert('donations', d.toRow());
    return d.copyWith(id: id);
  }

  Future<List<Donation>> listDonations() async {
    final db = await database;
    final rows =
        await db.query('donations', orderBy: 'created_at DESC', limit: 100);
    return rows.map(Donation.fromRow).toList();
  }

  Future<double> totalDonations() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COALESCE(SUM(amount_pln), 0) as total FROM donations');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ---------------------------------------------------------- code snippets

  Future<CodeSnippet> addCodeSnippet(CodeSnippet s) async {
    final db = await database;
    final id = await db.insert('code_snippets', s.toRow());
    return s.copyWith(id: id);
  }

  Future<List<CodeSnippet>> listCodeSnippets() async {
    final db = await database;
    final rows =
        await db.query('code_snippets', orderBy: 'created_at DESC', limit: 50);
    return rows.map(CodeSnippet.fromRow).toList();
  }

  // -------------------------------------------------------- users / RBAC

  Future<AppUser> addUser(AppUser u) async {
    final db = await database;
    final id = await db.insert('users', u.toRow());
    return u.copyWith(id: id);
  }

  Future<AppUser?> findUser(String username) async {
    final db = await database;
    final rows = await db.query('users',
        where: 'username = ?', whereArgs: [username], limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromRow(rows.first);
  }

  Future<List<AppUser>> listUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'created_at ASC');
    return rows.map(AppUser.fromRow).toList();
  }

  Future<void> updateUserRole(int id, String role) async {
    final db = await database;
    await db.update('users', {'role': role},
        where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------- comment agent log

  Future<void> addCommentLog(CommentAgentLog log) async {
    final db = await database;
    await db.insert('comment_agent_log', log.toRow());
  }

  Future<List<CommentAgentLog>> listCommentLogs() async {
    final db = await database;
    final rows = await db.query('comment_agent_log',
        orderBy: 'created_at DESC', limit: 50);
    return rows.map(CommentAgentLog.fromRow).toList();
  }

  // --------------------------------------------------------- radio tracks

  Future<RadioTrack> addRadioTrack(RadioTrack t) async {
    final db = await database;
    final id = await db.insert('radio_tracks', t.toRow());
    return t.copyWith(id: id);
  }

  Future<List<RadioTrack>> listRadioTracks() async {
    final db = await database;
    final rows = await db.query('radio_tracks', orderBy: 'added_at DESC');
    return rows.map(RadioTrack.fromRow).toList();
  }

  // ------------------------------------------------- messenger contacts

  Future<MessengerContact> addContact(MessengerContact c) async {
    final db = await database;
    final id = await db.insert('messenger_contacts', c.toRow());
    return c.copyWith(id: id);
  }

  Future<List<MessengerContact>> listContacts() async {
    final db = await database;
    final rows =
        await db.query('messenger_contacts', orderBy: 'display_name ASC');
    return rows.map(MessengerContact.fromRow).toList();
  }

  Future<void> addMessengerMessage(MessengerMessage m) async {
    final db = await database;
    await db.insert('messenger_messages', m.toRow());
  }

  Future<List<MessengerMessage>> messagesForContact(int contactId) async {
    final db = await database;
    final rows = await db.query('messenger_messages',
        where: 'contact_id = ?',
        whereArgs: [contactId],
        orderBy: 'timestamp ASC');
    return rows.map(MessengerMessage.fromRow).toList();
  }
}
