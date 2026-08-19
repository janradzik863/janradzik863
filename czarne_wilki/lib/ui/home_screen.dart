import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../engine/engine_manager.dart';
import '../services/moderation_service.dart';
import '../services/announcement_service.dart';
import 'agent/personalization_screen.dart';
import 'announcements/announcements_screen.dart';
import 'automation/automation_screen.dart';
import 'chat/chat_screen.dart';
import 'code/code_screen.dart';
import 'donations/donations_screen.dart';
import 'messenger/messenger_screen.dart';
import 'models/models_screen.dart';
import 'moderation/moderation_screen.dart';
import 'planner/planner_screen.dart';
import 'radio/radio_screen.dart';
import 'settings/settings_screen.dart';
import 'voices/voices_screen.dart';

/// Punkt 20: Spójna tożsamość projektu "Czarne Wilki Prawdy — Wszyscy Won!"
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engines = context.watch<EngineManager>();
    final mod = context.watch<ModerationService>();
    final announcements = context.watch<AnnouncementService>();

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
                'CZARNE WILKI PRAWDY',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                  color: CwColors.white,
                ),
              ),
            ),
            const Center(
              child: Text(
                'WSZYSCY WON!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: CwColors.crimson,
                ),
              ),
            ),
            const SizedBox(height: 6),
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
                if (mod.pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: '${mod.pendingCount} DO MODERACJI',
                    color: CwColors.offline,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            // --- Główne moduły ---
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
                  icon: Icons.calendar_month_outlined,
                  title: 'Planer',
                  subtitle: 'harmonogram postów',
                  onTap: () => _push(context, const PlannerScreen()),
                ),
                _HomeTile(
                  icon: Icons.lock_outlined,
                  title: 'Komunikator',
                  subtitle: 'szyfrowanie E2E',
                  onTap: () => _push(context, const MessengerScreen()),
                ),
                _HomeTile(
                  icon: Icons.radio,
                  title: 'Radio',
                  subtitle: 'wspólne słuchanie',
                  onTap: () => _push(context, const RadioScreen()),
                ),
                _HomeTile(
                  icon: Icons.code,
                  title: 'Kodowanie',
                  subtitle: 'asystent programisty',
                  onTap: () => _push(context, const CodeScreen()),
                ),
                _HomeTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Moderacja',
                  subtitle: '${mod.pendingCount} oczekujących',
                  onTap: () => _push(context, const ModerationScreen()),
                ),
                _HomeTile(
                  icon: Icons.campaign_outlined,
                  title: 'Ogłoszenia',
                  subtitle: '${announcements.unreadCount} nowych',
                  badge: announcements.unreadCount > 0,
                  onTap: () => _push(context, const AnnouncementsScreen()),
                ),
                _HomeTile(
                  icon: Icons.volunteer_activism,
                  title: 'Wsparcie',
                  subtitle: 'wesprzyj Wilki',
                  onTap: () => _push(context, const DonationsScreen()),
                ),
                _HomeTile(
                  icon: Icons.settings_outlined,
                  title: 'Ustawienia',
                  subtitle: 'tryb pracy, sync, RBAC',
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
                  'połączeń sieciowych. Komunikator szyfruje wiadomości od '
                  'końca do końca (AES-256-GCM). Każdy materiał generowany '
                  'przez AI trafia do kolejki moderacji przed opublikowaniem.',
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
    this.badge = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool badge;

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
              Row(
                children: [
                  Icon(icon, color: CwColors.crimson, size: 28),
                  if (badge) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: CwColors.crimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
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
                style: const TextStyle(color: CwColors.whiteDim, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
