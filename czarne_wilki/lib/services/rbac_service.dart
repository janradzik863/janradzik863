import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import 'crypto_service.dart';

/// Punkt 15: Hierarchiczny system kontroli dostępu (RBAC).
/// Role: admin (pełna kontrola), moderator (moderacja treści),
/// user (standardowy dostęp), viewer (tylko odczyt).
class RbacService extends ChangeNotifier {
  RbacService({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;
  final CryptoService _crypto = CryptoService.instance;

  AppUser? _currentUser;
  bool _setupComplete = false;

  AppUser? get currentUser => _currentUser;
  bool get setupComplete => _setupComplete;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get canModerate => _currentUser?.canModerate ?? false;
  bool get canPost => _currentUser?.canPost ?? false;

  /// Sprawdź czy istnieje administrator (pierwszy uruchomienie).
  Future<void> checkSetup() async {
    final users = await _db.listUsers();
    _setupComplete = users.isNotEmpty;

    // Auto-login jeśli jest tylko jeden użytkownik (właściciel urządzenia)
    if (users.length == 1) {
      _currentUser = users.first;
    }
    notifyListeners();
  }

  /// Pierwsza konfiguracja: utwórz konto głównego administratora.
  Future<bool> createAdmin(String username, String password) async {
    final existing = await _db.findUser(username);
    if (existing != null) return false;

    _crypto.init();
    final hash = _crypto.hashPassword(password);
    final user = await _db.addUser(AppUser(
      id: 0,
      username: username,
      passwordHash: hash,
      role: UserRole.admin,
    ));
    _currentUser = user;
    _setupComplete = true;
    notifyListeners();
    return true;
  }

  /// Logowanie.
  Future<bool> login(String username, String password) async {
    final user = await _db.findUser(username);
    if (user == null) return false;

    _crypto.init();
    if (!_crypto.verifyPassword(password, user.passwordHash)) return false;

    _currentUser = user;
    notifyListeners();
    return true;
  }

  /// Wylogowanie.
  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  /// Dodaj nowego użytkownika (tylko admin).
  Future<bool> addUser(String username, String password, UserRole role) async {
    if (!isAdmin) return false;

    _crypto.init();
    final hash = _crypto.hashPassword(password);
    await _db.addUser(AppUser(
      id: 0,
      username: username,
      passwordHash: hash,
      role: role,
    ));
    notifyListeners();
    return true;
  }

  /// Zmień rolę użytkownika (tylko admin).
  Future<bool> changeRole(int userId, UserRole newRole) async {
    if (!isAdmin) return false;
    await _db.updateUserRole(userId, newRole.name);
    notifyListeners();
    return true;
  }

  /// Lista użytkowników (tylko admin/moderator).
  Future<List<AppUser>> listUsers() async {
    if (!canModerate) return [];
    return _db.listUsers();
  }
}
