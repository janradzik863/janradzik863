import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/app_database.dart';
import 'engine/engine_manager.dart';
import 'engine/hf_repository.dart';
import 'engine/image_engine.dart';
import 'services/app_services.dart';
import 'ui/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CwApp());
}

class CwApp extends StatelessWidget {
  const CwApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: AppDatabase()),
        ChangeNotifierProvider(create: (_) => AgentProfileController()..load()),
        ChangeNotifierProvider(create: (_) => EngineManager()..load()),
        Provider<HfRepository>(create: (_) => HfRepository()),
        Provider<ImageEngine>(create: (_) => ImageEngine()),
        ChangeNotifierProvider(create: (_) => VoiceController()..init()),
        ChangeNotifierProxyProvider3<EngineManager, AgentProfileController,
            VoiceController, ChatController>(
          create: (context) => ChatController(
            engines: context.read<EngineManager>(),
            profile: context.read<AgentProfileController>(),
            voice: context.read<VoiceController>(),
          ),
          update: (context, engines, profile, voice, chat) => chat!,
        ),
        ChangeNotifierProxyProvider<EngineManager, AutomationController>(
          create: (context) =>
              AutomationController(engines: context.read<EngineManager>())..start(),
          update: (context, engines, previous) => previous!,
        ),
      ],
      child: MaterialApp(
        title: 'Czarne Wilki',
        debugShowCheckedModeBanner: false,
        theme: buildCwTheme(),
        home: const CwShell(),
      ),
    );
  }
}
