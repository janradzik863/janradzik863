# Architektura techniczna — „Czarne Wilki Prawdy"

## Stos

- **Framework:** Flutter 3.x (Dart >= 3.3.0)
- **UI / state:** `provider` (ChangeNotifier)
- **Natywne moduły:** Kotlin (Android), w tym `AccessibilityService`
- **Baza lokalna:** SQLite (`sqflite`) — historia konwersacji (#14)
- **Trwałość ustawień:** `shared_preferences`
- **Głosy (TTS):** `flutter_tts` (#3)
- **Sieć (tryb online):** `http` (OpenRouter/DeepSeek/OpenAI — #5)
- **Lokalna inferencja:** llama.cpp + Vulkan (moduł natywny, #4/#19)

## Warstwy

```
┌───────────────────────────────────────────────────────────────┐
│                          UI (Flutter)                         │
│   ChatScreen · VoiceLibraryScreen · AgentScreen ·             │
│   SettingsScreen · PlannerScreen · ModerationScreen           │
└────────────────────────────┬──────────────────────────────────┘
                             │  provider (AppState)
┌────────────────────────────▼──────────────────────────────────┐
│                          Services                             │
│   LlmService · VoiceService · SyncService                     │
└────────────────────────────┬──────────────────────────────────┘
                             │
┌────────────────────────────▼──────────────────────────────────┐
│                     Data (SQLite / prefs)                     │
│   AppDatabase (conversations, messages, publication_tasks)    │
└───────────────────────────────────────────────────────────────┘
                             ▲
┌────────────────────────────┴──────────────────────────────────┐
│               Natywna warstwa Android (Kotlin)                │
│   MainActivity (MethodChannel: sync)                          │
│   ScreenControlService (AccessibilityService: #8)             │
│   NativeLlmEngine (llama.cpp + Vulkan: #4/#19 — TODO)         │
└───────────────────────────────────────────────────────────────┘
```

## Pętla sprzężenia zwrotnego (automatyzacja ekranu, #8)

1. Użytkownik wydaje polecenie (głos / tekst / Telegram).
2. `ScreenControlService` rejestruje hierarchię `AccessibilityNodeInfo`
   i oblicza współrzędne elementów interaktywnych.
3. Dane układu trafiają do modelu AI z kontekstem zadania i wynikiem
   poprzedniej akcji.
4. AI wybiera kolejną akcję (kliknięcie współrzędnych, tekst, przewijanie).
5. `dispatchGesture` / `ACTION_SET_TEXT` wykonuje akcję.
6. Pętla trwa aż zadanie zostanie oznaczone jako ukończone
   (bez autozatrzymywania — jawne Stop, #2).

### Agent automatyzacji — pełna implementacja

- `lib/services/agent/screen_control_bridge.dart` — most Dart→Kotlin
  (MethodChannel `czarne_wilki/screen`): hierarchia, klik po współrzędnych,
  klik po tekście, wpisywanie tekstu, przewijanie, akcje globalne.
- `lib/services/agent/agent_action.dart` — model akcji + odporny parser JSON
  (toleruje markdown i dodatkowy tekst od modelu).
- `lib/services/agent/agent_controller.dart` — rdzeń pętli sprzężenia
  zwrotnego: rejestracja ekranu → prompt → decyzja AI → wykonanie → powtórka
  (limit kroków, log, obsługa błędów).
- `android/.../ScreenControlService.kt` — rozszerzona warstwa natywna:
  `scroll`, `performGlobalAction`, `describeTextNodes` (pełna hierarchia),
  `findEditableAndType`.
- `lib/features/automation/automation_screen.dart` — UI: polecenie, log kroków,
  podsumowanie, sterowanie głosowe (STT przez `speech_to_text`).
- Dostawcy AI: OpenRouter / **DeepSeek** / OpenAI (chipy szybkiego wyboru
  Base URL w ustawieniach). Modele DeepSeek: `deepseek-chat`, `deepseek-reasoner`.

### Zdalny dostęp przez Telegram

- `lib/services/telegram/telegram_service.dart` — ankieta w tle
  (long-polling `getUpdates`), odbiór poleceń i wysyłka postępu
  (`sendMessage`). Po włączeniu uruchamia **usługę pierwszoplanową**
  (`TelegramForegroundService.kt`), dzięki czemu nasłuch działa, gdy
  aplikacja jest w tle.
- `lib/features/telegram/telegram_screen.dart` — konfiguracja tokenu i
  przełącznik integracji.
- Polecenia z Telegrama uruchamiają agenta automatycznie (sprzęg w
  `AutomationScreen.didChangeDependencies`).

### Ręczny mikrofon (#2) i lokalna inferencja (#4/#19)

- `android/.../MicrophoneService.kt` — ciągły nasłuch PCM16 (AudioRecord),
  **bez autozatrzymywania**; stop wyłącznie jawnym poleceniem.
- `lib/services/audio/mic_service.dart` — most Dart (`czarne_wilki/mic`),
  podłączony do `AppState.startListening/stopListening`.
- `lib/services/llm_service.dart` — tryb offline woła natywny silnik
  (`LocalInferenceService.generate`) zamiast komunikatu zastępczego.
- `lib/services/model_repository.dart` + `lib/features/models/models_screen.dart`
  — pobieranie modeli GGUF z zewnętrznych repozytoriów (Hugging Face / URL)
  z postępem, lista zainstalowanych modeli i ładowanie do silnika.

## Synchronizacja międzyplatformowa (#1)

`SyncService` (MethodChannel `czarne_wilki/sync`) jest mostem między Androidem
a desktopem. Docelowo transportem jest szyfrowany kanał WebRTC DataChannel
(Signal Protocol) — pełna ścieżka E2E bez pośredników.

## Komunikator i radio (#12, #13)

### Szyfrowany komunikator (#12) — zaimplementowany

- `lib/services/messenger/crypto.dart` — schemat **Ephemeral X25519 + HKDF-SHA256
  + AES-256-GCM**: świeża para efemeryczna per wiadomość (forward secrecy),
  poufność + integralność, implicite uwierzytelnienie nadawcy przez udany DH.
- `lib/services/messenger/messenger_service.dart` — transport (WebSocket do
  relay; serwer widzi tylko koperty E2E), kontakty, grupy (szyfrowanie
  per-odbiorca), trwała tożsamość (`shared_preferences`).
- `lib/features/messenger/messenger_screen.dart` — UI.

Rozszerzenie do pełnego Double Ratchet (Signal) jest udokumentowanym kolejnym
krokiem; kontrakt kopert jest z nim zgodny.

### Radio społecznościowe (#13) — zaimplementowane

- `lib/services/radio/radio_service.dart` — wspólna kolejka audio, stan
  odtwarzania, synchronizacja pozycji w czasie rzeczywistym (wspólny zegar
  serwera + offset lokalny → każdy słuchacz słyszy ten sam moment utworu).
- `lib/services/radio/radio_transport.dart` — kanał sygnalizacyjny WebSocket
  (join/queue/sync/offer/answer/candidate); sam strumień audio idzie
  peer-to-peer przez WebRTC (DataChannel / MediaStream), bez pośredników.
- `lib/features/radio/radio_screen.dart` — UI (now playing, sterowanie,
  kolejka, licznik słuchaczy).

Integracja WebRTC (plugin `flutter_webrtc`) jest udokumentowanym kolejnym
krokiem — kontrakt sygnalizacji jest gotowy.

## RBAC i moderacja (#15, #16) — zaimplementowane

- `lib/services/auth/rbac.dart` — role (`admin/moderator/member/guest`),
  uprawnienia (matryca `AccessControl.can`). Główny administrator ma pełnię praw.
- `lib/services/auth/auth_service.dart` — użytkownicy, role, trwałość
  (`shared_preferences`), bootstrap administratora, ochrona przed degradacją siebie.
- `lib/services/moderation/moderation_service.dart` — kolejka materiałów
  (`pending/approved/rejected`); kontroler jakości (#22) = krok akceptacji.
- `lib/features/admin/admin_screen.dart` — zarządzanie użytkownikami i rolami.
- `lib/features/moderation/moderation_screen.dart` — zatwierdzanie/odrzucanie
  treści (bramkowane uprawnieniem `moderateContent`/`approveMaterials`).

## Asystent kodowania i samonaprawa (#10, #11)

- `lib/services/coder/coder_service.dart` — generowanie/refaktor kodu przez
  aktywny model (`LlmService.raw`), wybór języka.
- `lib/features/coder/coder_screen.dart` — UI (opis → kod, kopiowanie).
- Samonaprawa / iniekcja w locie (#11):
  - Android — `SelfHealService.kt`: `DexClassLoader` ładuje klasy z pliku `.dex`
    do bieżącego procesu bez reinstalacji; wywołanie metod przez refleksję.
  - Desktop — `SelfHealService.applySourcePatch`: modyfikacja plików źródłowych
    (bezpieczna edycja z markerem).
  - Dart — `lib/services/selfheal/self_heal_service.dart` (MethodChannel
    `czarne_wilki/selfheal`) + `self_heal_screen.dart`.

## Dobrowolne wpłaty (#21) — zaimplementowane

- `lib/services/support/support_service.dart` — kanały wsparcia (BTC/ETH/BLIK),
  lokalny rejestr zadeklarowanych wpłat (bez danych płatniczych), łączna suma,
  pobieranie adresu portfela (online z fallbackiem statycznym).
- `lib/features/support/support_screen.dart` — UI: suma wsparcia, lista metod,
  kopiowanie adresu, deklaracja kwoty.

## Ogłoszenia, alerty i agent komentarzy (#17, #18) — zaimplementowane

- `lib/services/notifications/notification_service.dart` — natywne kanały
  powiadomień (`flutter_local_notifications` → `NotificationChannel`),
  dwa kanały: alerty (max) i ogłoszenia (default).
- `lib/services/notifications/announcements_service.dart` — ogłoszenia z
  priorytetami (`low/normal/high/critical`); publikacja wywołuje kanał natywny.
- `lib/features/announcements/announcements_screen.dart` — lista + publikacja
  (bramkowane `publishPosts`).
- `lib/services/comments/comments_service.dart` — komentarze + auto-odpowiedzi
  aktywnego agenta (przełącznik), generowane przez `LlmService`.
- `lib/features/comments/comments_screen.dart` — widok komentarzy z odpowiedziami
  agenta + kompozytor (`CommentComposer`).

## Bezpieczeństwo

- Klucze API przechowywane lokalnie (`shared_preferences`), wysyłane wyłącznie
  do wskazanego dostawcy (#5).
- Historia konwersacji wyłącznie na urządzeniu (#14).
- Komunikator szyfrowany E2E (#12).
