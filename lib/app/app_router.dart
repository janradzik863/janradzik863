import 'package:flutter/material.dart';

import '../features/agent/agent_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/automation/automation_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/coder/coder_screen.dart';
import '../features/comments/comments_screen.dart';
import '../features/messenger/messenger_screen.dart';
import '../features/models/models_screen.dart';
import '../features/moderation/moderation_screen.dart';
import '../features/planner/planner_screen.dart';
import '../features/radio/radio_screen.dart';
import '../features/selfheal/self_heal_screen.dart';
import '../features/settings/module_settings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/support/support_screen.dart';
import '../features/telegram/telegram_screen.dart';
import '../features/voice/voice_library_screen.dart';

class AppRouter {
  static const home = '/';
  static const voiceLibrary = '/voice';
  static const agent = '/agent';
  static const settings = '/settings';
  static const planner = '/planner';
  static const moderation = '/moderation';
  static const messenger = '/messenger';
  static const radio = '/radio';
  static const admin = '/admin';
  static const coder = '/coder';
  static const announcements = '/announcements';
  static const comments = '/comments';
  static const selfHeal = '/selfheal';
  static const support = '/support';
  static const automation = '/automation';
  static const telegram = '/telegram';
  static const models = '/models';
  static const moduleSettings = '/module_settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _page(const ChatScreen(), settings);
      case voiceLibrary:
        return _page(const VoiceLibraryScreen(), settings);
      case agent:
        return _page(const AgentScreen(), settings);
      case settings:
        return _page(const SettingsScreen(), settings);
      case planner:
        return _page(const PlannerScreen(), settings);
      case moderation:
        return _page(const ModerationScreen(), settings);
      case messenger:
        return _page(const MessengerScreen(), settings);
      case radio:
        return _page(const RadioScreen(), settings);
      case admin:
        return _page(const AdminScreen(), settings);
      case coder:
        return _page(const CoderScreen(), settings);
      case announcements:
        return _page(const AnnouncementsScreen(), settings);
      case comments:
        return _page(const CommentsScreen(), settings);
      case selfHeal:
        return _page(const SelfHealScreen(), settings);
      case support:
        return _page(const SupportScreen(), settings);
      case automation:
        return _page(const AutomationScreen(), settings);
      case telegram:
        return _page(const TelegramScreen(), settings);
      case models:
        return _page(const ModelsScreen(), settings);
      case moduleSettings:
        return _page(const ModuleSettingsScreen(), settings);
      default:
        return _page(const ChatScreen(), settings);
    }
  }

  static MaterialPageRoute<T> _page<T>(Widget w, RouteSettings s) =>
      MaterialPageRoute<T>(builder: (_) => w, settings: s);
}
