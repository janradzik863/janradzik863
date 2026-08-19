# Mapowanie 22 wymagań → kod

| # | Wymaganie | Plik / moduł |
|---|---|---|
| 1 | Synchronizacja międzyplatformowa | `lib/services/sync_service.dart`, `MainActivity.kt` |
| 2 | Ręczny mikrofon, nasłuch do Stop (bez auto-stop) | `lib/state/app_state.dart`, `ChatScreen._InputBar` |
| 3 | Biblioteka głosów AI (odsłuch + przełączanie) | `lib/services/voice_service.dart`, `voice_library_screen.dart` |
| 4 | Lokalne modele AI + zewnętrzne repozytoria | `NativeLlmEngine.kt` + `llama_jni.cpp` + `ModelRepository` + `LocalInferenceService` |
| 5 | Przełącznik Sieciowy / Offline | `lib/state/app_state.dart`, `settings_screen.dart`, `chat_screen.dart` |
| 6 | Minimalistyczny czat + menu „+" | `lib/features/chat/chat_screen.dart` |
| 7 | Planer publikacji | `lib/features/planner/planner_screen.dart`, `publication_tasks` (SQLite) |
| 8 | Autonomiczny montaż (Accessibility) | `ScreenControlService.kt` + `lib/services/agent/` (pętla sprzężenia zwrotnego: `agent_controller.dart`, `screen_control_bridge.dart`, `agent_action.dart`) |
| 9 | Personalizacja agenta | `lib/features/agent/agent_screen.dart`, `AgentConfig` |
| 10 | Asystent kodowania | `lib/services/coder/coder_service.dart` + `coder_screen.dart` |
| 11 | Samonaprawa / iniekcja kodu | `lib/services/selfheal/self_heal_service.dart` + `self_heal_screen.dart` + `SelfHealService.kt` (DexClassLoader) |
| 12 | Szyfrowany komunikator E2E (grupy) | `lib/services/messenger/crypto.dart` (X25519+HKDF+AES-GCM), `messenger_service.dart`, `messenger_screen.dart` |
| 13 | Radio społecznościowe | `lib/services/radio/radio_service.dart` + `radio_transport.dart` + `radio_screen.dart` |
| 14 | Lokalna historia (SQLite) | `lib/data/database.dart` |
| 15 | RBAC + administrator | `lib/services/auth/rbac.dart` + `auth_service.dart` + `admin_screen.dart` |
| 16 | Panel moderacji | `lib/services/moderation/moderation_service.dart` + `moderation_screen.dart` |
| 17 | Ogłoszenia / alerty (kanały powiadomień) | `lib/services/notifications/notification_service.dart` + `announcements_service.dart` + `announcements_screen.dart` |
| 18 | Agent w komentarzach | `lib/services/comments/comments_service.dart` + `comments_screen.dart` |
| 19 | Tryb bez maski (otwarte modele on-device) | `NativeLlmEngine.kt` (llama.cpp, GPU/Vulkan) + `LocalInferenceService` |
| 20 | Tożsamość + logo | `lib/core/constants.dart`, `assets/images/logo.png` |
| 21 | Dobrowolne wpłaty | `lib/services/support/support_service.dart` + `support_screen.dart` |
| 22 | Wieloagent + kontroler jakości | `ModerationService` (kolejka + zatwierdzanie) — kontroler jakości = krok akceptacji #16 |

Wszystkie 22 wymagania mają przypisany moduł. Uwaga o szczerości zakresu:
kilka elementów to działające interfejsy + pełna logika (transport E2E,
synchronizacja, moderacja), natomiast warstwy wymagające zewnętrznych
składników (plugin WebRTC do strumienia audio, podmoduł llama.cpp do lokalnej
inferencji, klucze API) są udokumentowane jako jawne punkty podłączenia —
nie jako zakończona integracja sprzętowa.
