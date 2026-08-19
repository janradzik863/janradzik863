import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'data/database.dart';
import 'services/auth/auth_service.dart';
import 'services/comments/comments_service.dart';
import 'services/messenger/messenger_service.dart';
import 'services/moderation/moderation_service.dart';
import 'services/notifications/announcements_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/radio/radio_service.dart';
import 'services/settings/app_settings.dart';
import 'services/support/support_service.dart';
import 'services/telegram/telegram_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicjalizacja lokalnej bazy danych (historia konwersacji — wymaganie #14).
  final db = AppDatabase();
  await db.open();

  // Szyfrowany komunikator (tożsamość E2E — wymaganie #12).
  final messenger = MessengerService();
  await messenger.init();

  // RBAC: użytkownicy i role (wymaganie #15).
  final auth = AuthService();
  await auth.init();

  // Moderacja treści (wymaganie #16).
  final moderation = ModerationService();

  // Radio społecznościowe (wymaganie #13).
  final radio = RadioService()..seed();

  // Ogłoszenia i alerty priorytetowe (wymaganie #17).
  final notifications = NotificationService();
  await notifications.init();
  final announcements = AnnouncementsService(notifications);

  // Aktywny agent w komentarzach (wymaganie #18).
  final comments = CommentsService();
  await comments.load();

  // Dobrowolne wpłaty i wsparcie społecznościowe (wymaganie #21).
  final support = SupportService();
  await support.init();

  // Telegram — zdalny dostęp agenta (polling w tle).
  final telegram = TelegramService();
  await telegram.load();

  // Ustawienia wszystkich modułów.
  final settings = AppSettings();
  await settings.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(db)..load()),
        ChangeNotifierProvider.value(value: messenger),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: moderation),
        ChangeNotifierProvider.value(value: radio),
        ChangeNotifierProvider.value(value: announcements),
        ChangeNotifierProvider.value(value: comments),
        ChangeNotifierProvider.value(value: support),
        ChangeNotifierProvider.value(value: telegram),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const CzarneWilkiApp(),
    ),
  );
}
