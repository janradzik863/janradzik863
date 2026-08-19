import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'rbac.dart';

/// Zarządza użytkownikami, rolami i aktualną tożsamością (wymaganie #15).
///
/// Przy pierwszym uruchomieniu tworzy bootstrapowego głównego administratora.
class AuthService extends ChangeNotifier {
  final Map<String, User> _users = {};
  User? _currentUser;

  User? get currentUser => _currentUser;
  List<User> get users => _users.values.toList();

  static const _prefUsers = 'auth.users';
  static const _prefCurrent = 'auth.current';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefUsers);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final u = User.fromJson(e as Map<String, dynamic>);
        _users[u.id] = u;
      }
    } else {
      final admin = User(
        id: const Uuid().v4(),
        name: 'Główny Administrator',
        role: Role.admin,
      );
      _users[admin.id] = admin;
      await _save();
    }
    final curId = prefs.getString(_prefCurrent);
    _currentUser = (curId != null && _users.containsKey(curId))
        ? _users[curId]
        : _users.values.firstWhere(
            (u) => u.role == Role.admin,
            orElse: () => _users.values.first,
          );
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefUsers,
      jsonEncode(_users.values.map((u) => u.toJson()).toList()),
    );
  }

  /// Skrót sprawdzania uprawnień aktualnego użytkownika.
  bool can(Permission p) => AccessControl.can(_currentUser, p);

  /// Przełącza aktywną tożsamość (do celów demo RBAC).
  Future<void> switchUser(String id) async {
    if (!_users.containsKey(id)) return;
    _currentUser = _users[id];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCurrent, id);
    notifyListeners();
  }

  /// Dodaje użytkownika (tylko z prawem assignRoles).
  Future<bool> addUser(String name, Role role) async {
    if (!AccessControl.can(_currentUser, Permission.assignRoles)) return false;
    final u = User(id: const Uuid().v4(), name: name, role: role);
    _users[u.id] = u;
    await _save();
    notifyListeners();
    return true;
  }

  /// Zmienia rolę użytkownika (tylko z prawem assignRoles; nie można
  /// zdegradować samego siebie — ochrona głównego administratora).
  Future<bool> assignRole(String id, Role role) async {
    if (!AccessControl.can(_currentUser, Permission.assignRoles)) return false;
    if (_currentUser != null && id == _currentUser!.id) return false;
    final u = _users[id];
    if (u == null) return false;
    u.role = role;
    await _save();
    notifyListeners();
    return true;
  }
}
