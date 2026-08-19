import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../engine/engine_manager.dart';
import 'agent/personalization_screen.dart';
import 'automation/automation_screen.dart';
import 'chat/chat_screen.dart';
import 'models/models_screen.dart';
import 'settings/settings_screen.dart';
import 'voices/voices_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engines = context.watch<EngineManager>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            const Center(child: CwLogo(width: 190)),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'CZARNE WILKI',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: CwColors.white,
                ),
              ),
            ),
            const Center(
              child: Text(
                'prywatny asystent AI — twoje urządzenie, twoje zasady',
                style: TextStyle(color: CwColors.whiteDim, fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
            const CwFlagStrip(),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusChip(
                  label: engines.online ? 'SIECIOWY' : 'OFFLINE',
                  color: engines.online ? CwColors.online : CwColors.offline,
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: engines.activeModel?.displayName ?? 'BRAK MODELU',
                  color: CwColors.crimson,
                ),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _HomeTile(
                  icon: Icons.forum_outlined,
                  title: 'Czat',
                  subtitle: 'rozmowa i generowanie',
                  onTap: () => _push(context, const ChatScreen()),
                ),
                _HomeTile(
                  icon: Icons.memory_outlined,
                  title: 'Modele',
                  subtitle: 'lokalne GGUF i chmura',
                  onTap: () => _push(context, const ModelsScreen()),
                ),
                _HomeTile(
                  icon: Icons.record_voice_over_outlined,
                  title: 'Głosy',
                  subtitle: 'biblioteka i odsłuch',
                  onTap: () => _push(context, const VoicesScreen()),
                ),
                _HomeTile(
                  icon: Icons.smart_toy_outlined,
                  title: 'Agent',
                  subtitle: 'imię, rola, charakter',
                  onTap: () => _push(context, const PersonalizationScreen()),
                ),
                _HomeTile(
                  icon: Icons.precision_manufacturing_outlined,
                  title: 'Automatyzacja',
                  subtitle: 'zadania na urządzeniu',
                  onTap: () => _push(context, const AutomationScreen()),
                ),
                _HomeTile(
                  icon: Icons.settings_outlined,
                  title: 'Ustawienia',
                  subtitle: 'tryb pracy, prywatność',
                  onTap: () => _push(context, const SettingsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Historia rozmów jest zapisywana wyłącznie na tym urządzeniu '
                  '(SQLite). W trybie Offline aplikacja nie nawiązuje żadnych '
                  'połączeń sieciowych.',
                  style: TextStyle(color: CwColors.whiteDim, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: CwColors.crimson, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: CwColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style:
                    const TextStyle(color: CwColors.whiteDim, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
