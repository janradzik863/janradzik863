import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'agent/personalization_screen.dart';
import 'automation/automation_screen.dart';
import 'chat/chat_screen.dart';
import 'home_screen.dart';
import 'models/models_screen.dart';
import 'settings/settings_screen.dart';
import 'voices/voices_screen.dart';

/// Adaptacyjna nawigacja aplikacji.
///
/// Wąski ekran (telefon): klasyczny ekran startowy z kaflami.
/// Szeroki ekran (desktop): stała szyna nawigacyjna z logotypem
/// i przełączanymi ekranami — wszystko na jednym widoku.
class CwShell extends StatefulWidget {
  const CwShell({super.key});

  @override
  State<CwShell> createState() => _CwShellState();
}

class _CwShellState extends State<CwShell> {
  int _index = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    ChatScreen(),
    ModelsScreen(),
    VoicesScreen(),
    PersonalizationScreen(),
    AutomationScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (!wide) return _screens.first;
        return Scaffold(
          body: Row(
            children: [
              _CwRail(
                index: _index,
                onSelect: (i) => setState(() => _index = i),
              ),
              const VerticalDivider(width: 1, color: Color(0x14FFFFFF)),
              Expanded(child: _screens[_index]),
            ],
          ),
        );
      },
    );
  }
}

class _CwRail extends StatelessWidget {
  const _CwRail({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _labels = [
    'Start',
    'Czat',
    'Modele',
    'Głosy',
    'Agent',
    'Automatyzacja',
    'Ustawienia',
  ];

  static const _icons = [
    Icons.home_outlined,
    Icons.forum_outlined,
    Icons.memory_outlined,
    Icons.record_voice_over_outlined,
    Icons.smart_toy_outlined,
    Icons.precision_manufacturing_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      backgroundColor: CwColors.black,
      selectedIndex: index,
      onDestinationSelected: onSelect,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: CwColors.white),
      selectedLabelTextStyle: const TextStyle(
        color: CwColors.white,
        fontWeight: FontWeight.w800,
        fontSize: 11,
      ),
      unselectedLabelTextStyle:
          const TextStyle(color: CwColors.whiteDim, fontSize: 11),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            const CwLogo(width: 64),
            const SizedBox(height: 6),
            Container(
              width: 48,
              height: 2,
              color: CwColors.crimson,
            ),
          ],
        ),
      ),
      destinations: [
        for (var i = 0; i < _icons.length; i++)
          NavigationRailDestination(
            icon: Icon(
              _icons[i],
              color: i == index ? CwColors.crimson : CwColors.whiteDim,
            ),
            selectedIcon: Icon(_icons[i], color: CwColors.crimson),
            label: Text(_labels[i]),
          ),
      ],
    );
  }
}
