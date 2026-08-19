/// Hierarchiczny system kontroli dostępu oparty o role — RBAC (wymaganie #15).
library;

enum Role { admin, moderator, member, guest }

enum Permission {
  viewChat,
  sendMessage,
  generateContent,
  publishPosts,
  moderateContent,
  approveMaterials,
  manageUsers,
  assignRoles,
  manageRadio,
}

/// Użytkownik z przypisaną rolą.
class User {
  final String id;
  final String name;
  Role role;

  User({required this.id, required this.name, required this.role});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
      };

  static User fromJson(Map<String, dynamic> m) => User(
        id: m['id'] as String,
        name: m['name'] as String,
        role: Role.values.byName(m['role'] as String),
      );
}

/// Matryca uprawnień. Główny administrator ma pełnię praw (wymaganie #15).
class AccessControl {
  static const Map<Role, Set<Permission>> _matrix = {
    Role.admin: {
      Permission.viewChat,
      Permission.sendMessage,
      Permission.generateContent,
      Permission.publishPosts,
      Permission.moderateContent,
      Permission.approveMaterials,
      Permission.manageUsers,
      Permission.assignRoles,
      Permission.manageRadio,
    },
    Role.moderator: {
      Permission.viewChat,
      Permission.sendMessage,
      Permission.generateContent,
      Permission.publishPosts,
      Permission.moderateContent,
      Permission.approveMaterials,
      Permission.manageRadio,
    },
    Role.member: {
      Permission.viewChat,
      Permission.sendMessage,
      Permission.generateContent,
      Permission.publishPosts,
      Permission.manageRadio,
    },
    Role.guest: {
      Permission.viewChat,
    },
  };

  static bool can(User? user, Permission p) =>
      user != null && _matrix[user.role]!.contains(p);
}
