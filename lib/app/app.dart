import 'package:flutter/material.dart';

import 'app_router.dart';
import 'theme.dart';

class CzarneWilkiApp extends StatelessWidget {
  const CzarneWilkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Czarne Wilki Prawdy',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
