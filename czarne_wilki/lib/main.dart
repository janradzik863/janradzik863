import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/app_database.dart';
import 'engine/engine_manager.dart';
import 'engine/hf_repository.dart';
import 'engine/image_engine.dart';
import 'services/announcement_service.dart';
import 'services/app_services.dart';
import 'services/code_assistant_service.dart';
import 'services/comment_agent_service.dart';
import 'services/donation_service.dart';
import 'services/moderation_service.dart';
import 'services/notification_service.dart';
import 'services/planner_service.dart';
import 'services/radio_service.dart';
import 'services/rbac_service.dart';
import 'services/sync_bridge.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicjalizacja powiadomień natywnych (pkt 17)
  await NotificationService.instance.init();

  runApp(const CwApp());
}

class CwApp extends StatelessWidget {
  const CwApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --- Baza danych ---
        Provider<AppDatabase>.value(value: AppDatabase()),

        // --- Punkt 1: Synchronizacja międzyplatformowa ---
        ChangeNotifierProvider(create: (_) => SyncBridge()),

        // --- Punkt 9: Personalizacja agenta ---
        ChangeNotifierProvider(create: (_) => AgentProfileController()..load()),

        // --- Punkt 5: Przełącznik trybu Sieciowy/Offline ---
        ChangeNotifierProvider(create: (_) => EngineManager()..load()),

        // --- Punkt 4: Repozytoria modeli (HuggingFace) ---
        Provider<HfRepository>(create: (_) => HfRepository()),

        // --- Punkt 6: Generowanie obrazów ---
        Provider<ImageEngine>(create: (_) => ImageEngine()),

        // --- Punkt 3: Biblioteka głosów ---
        ChangeNotifierProvider(create: (_) => VoiceController()..init()),

        // --- Punkt 15: RBAC ---
        ChangeNotifierProvider(create: (_) => RbacService()..checkSetup()),

        // --- Punkt 16 + 22: Moderacja / Kontroler jakości ---
        ChangeNotifierProvider(create: (_) => ModerationService()..refresh()),

        // --- Punkt 7: Planer publikacji ---
        ChangeNotifierProvider(create: (_) => PlannerService()..load()),

        // --- Punkt 17: Ogłoszenia ---
        ChangeNotifierProvider(create: (_) => AnnouncementService()..load()),

        // --- Punkt 21: Wpłaty ---
        ChangeNotifierProvider(create: (_) => DonationService()..load()),

        // --- Punkt 10 + 11: Asystent kodowania ---
        ChangeNotifierProvider(create: (_) => CodeAssistantService()..load()),

        // --- Punkt 13: Radio ---
        ChangeNotifierProxyProvider<SyncBridge, RadioService>(
          create: (context) => RadioService(
            syncBridge: context.read<SyncBridge>(),
          )..load(),
          update: (context, sync, previous) => previous!,
        ),

        // --- Punkt 18: Agent komentarzy ---
        ChangeNotifierProxyProvider<ModerationService, CommentAgentService>(
          create: (context) => CommentAgentService(
            moderation: context.read<ModerationService>(),
          )..load(),
          update: (context, mod, previous) => previous!,
        ),

        // --- Czat (łączy: pkt 2, 6, 14) ---
        ChangeNotifierProxyProvider3<EngineManager, AgentProfileController,
            VoiceController, ChatController>(
          create: (context) => ChatController(
            engines: context.read<EngineManager>(),
            profile: context.read<AgentProfileController>(),
            voice: context.read<VoiceController>(),
          ),
          update: (context, engines, profile, voice, chat) => chat!,
        ),

        // --- Punkt 8: Automatyzacja ---
        ChangeNotifierProxyProvider<EngineManager, AutomationController>(
          create: (context) =>
              AutomationController(engines: context.read<EngineManager>())
                ..start(),
          update: (context, engines, previous) => previous!,
        ),
      ],
      child: MaterialApp(
        title: 'Czarne Wilki Prawdy — Wszyscy Won!',
        debugShowCheckedModeBanner: false,
        theme: buildCwTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
