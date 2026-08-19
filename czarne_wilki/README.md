# 🐺 Czarne Wilki Prawdy — Wszyscy Won!

**Prywatny asystent AI: lokalne modele GGUF, chmura, głosy, automatyzacja urządzenia, szyfrowany komunikator E2E, radio społecznościowe, system moderacji, planer publikacji.**

![Logo](assets/logo/cwp_logo.jpeg)

Natywna aplikacja mobilna (Android) i desktopowa (Linux/Windows) zbudowana w technologii **Flutter** z natywnymi modułami **Kotlin**. Kategorycznie odrzuca rozwiązania webowe i przeglądarkowe.

---

## 📦 Kompilacja i instalacja

### Wymagania

| Narzędzie | Wersja | Instalacja |
|-----------|--------|------------|
| Flutter SDK | ≥ 3.3.0 | [flutter.dev](https://flutter.dev) |
| Android SDK | API 28+ (target 35) | Android Studio |
| JDK | 17 | `sudo apt install openjdk-17-jdk-headless` |
| NDK | Dołączony do SDK | Android Studio → SDK Manager |
| clang, cmake, ninja | (desktop) | `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev` |

### Android APK

```bash
cd czarne_wilki
flutter pub get

# Debug APK:
flutter build apk --debug

# Release APK:
flutter build apk --release

# Release split per ABI (zalecane):
flutter build apk --release --split-per-abi
```

Wynikowy plik: `build/app/outputs/flutter-apk/app-release.apk`

Lub użyj skryptu:
```bash
./tools/build_apk.sh release
```

### Desktop Linux

```bash
cd czarne_wilki
flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release
```

Wynikowy plik: `build/linux/x64/release/bundle/czarne_wilki`

Lub użyj skryptu:
```bash
./tools/build_desktop.sh linux release
```

### CI/CD (GitHub Actions)

Workflow `.github/workflows/build.yml` automatycznie kompiluje APK i Desktop Linux przy każdym push do `main`. Przy tagowaniu wersji (`v1.0.0`) tworzy GitHub Release z gotowymi plikami.

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## 🏗 22 Kluczowe Wymagania Funkcjonalne

### 1. Synchronizacja międzyplatformowa w czasie rzeczywistym
Most WebSocket między telefonem a komputerem. Desktop = serwer, telefon = klient. Synchronizacja stanu czatu, radia i automatyzacji.

### 2. Ręczne sterowanie mikrofonem
Ciągły nasłuch aż do wciśnięcia STOP. Autozatrzymywanie całkowicie wyłączone — pętla restartuje sesję po każdej przerwie ciszy.

### 3. Biblioteka głosów AI
Przeglądanie, odsłuch próbek i przełączanie głosu TTS. Regulacja tempa i wysokości. Głosy polskie na szczycie listy.

### 4. Natywna integracja lokalnych modeli AI
llama.cpp przez FFI (llama_cpp_dart). Obsługa formatów ChatML, Llama-2, Gemma, Mistral. Pobieranie modeli GGUF z HuggingFace.

### 5. Przełącznik trybu Sieciowy/Offline
Offline = 100% na urządzeniu, zero połączeń. Sieciowy = chmura dozwolona (OpenRouter, DeepSeek, OpenAI-compatible).

### 6. Minimalistyczny czat z menu „+"
Generowanie tekstu, obrazu (Pollinations.AI), dźwięku (TTS) i opisu wideo w jednym interfejsie.

### 7. Planer publikacji
Harmonogram dat, godzin i platform (Facebook, Instagram, X, Telegram, TikTok). Statusy: szkic → zaplanowany → opublikowany.

### 8. Autonomiczna automatyzacja urządzenia
Pętla sprzężenia zwrotnego: ekran → AI → akcja → ekran. Natywna usługa dostępności Androida (CwAccessibilityService.kt).

### 9. Personalizacja agenta
Edycja imienia, roli i pełnej instrukcji systemowej (System Prompt). Regulacja temperatury. Podgląd efektywnego promptu.

### 10. Asystent kodowania
Generowanie kodu w 8 językach (Dart, Kotlin, Python, JS, Rust, SQL, HTML, Bash). Historia snippetów. Kopiowanie i zapis do pliku.

### 11. Mechanizm samonaprawy
Przycisk „Napraw" — AI analizuje błędy i regeneruje poprawiony kod. Na desktopie: zapis do katalogu projektu.

### 12. Szyfrowany komunikator E2E
AES-256-GCM + RSA-2048 wymiana kluczy. Lista kontaktów z kluczami publicznymi. Połączenia głosowe/wideo (WebRTC P2P).

### 13. Radio społecznościowe
Biblioteka utworów, kolejka odtwarzania, synchronizacja między urządzeniami przez SyncBridge.

### 14. Lokalna pamięć historii
SQLite na urządzeniu. Pełna historia dostępna dla każdego nowego modelu — zmiana silnika nie traci kontekstu.

### 15. System RBAC
Role: Admin, Moderator, Użytkownik, Czytelnik. Admin tworzy konta, zarządza rolami. SHA-256 hashowanie haseł.

### 16. Panel moderacji
Kolejka zatwierdzania treści. Statusy: oczekujące → zatwierdzone / odrzucone. Filtrowanie po statusie.

### 17. Ogłoszenia i alerty
Natywne kanały powiadomień Android (`cw_alerts`, `cw_general`). Priorytety: normalny, wysoki, krytyczny.

### 18. Agent komentarzy
Generuje odpowiedzi na komentarze → wysyła do kolejki moderacji (pkt 22) → NIE publikuje bez zatwierdzenia.

### 19. Tryb bez maski
Przełącznik: model odpowiada na KAŻDE pytanie bez filtrów. Działa z otwartymi modelami (abliterated/uncensored).

### 20. Tożsamość projektu
"Czarne Wilki Prawdy — Wszyscy Won!" — biało-czerwono-czarna oprawa, logo na ekranie startowym, w nagłówkach i ikonie.

### 21. Wpłaty i wsparcie
Formularz dobrowolnych wpłat. Lista wspierających z wiadomościami. Podsumowanie zebranej kwoty.

### 22. Architektura wieloagentowa z kontrolerem jakości
Każdy materiał generowany przez AI trafia do kolejki moderacji (ModerationService) przed wydaniem. Admin/Moderator zatwierdza.

---

## 🏛 Architektura

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  HomeScreen · ChatScreen · ModelsScreen · VoicesScreen       │
│  PlannerScreen · MessengerScreen · RadioScreen · CodeScreen  │
│  ModerationScreen · AnnouncementsScreen · DonationsScreen    │
│  AutomationScreen · PersonalizationScreen · SettingsScreen   │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Controllers / Services                     │
│  ChatController · AutomationController · VoiceController     │
│  PlannerService · ModerationService · RbacService            │
│  RadioService · DonationService · AnnouncementService        │
│  CodeAssistantService · CommentAgentService · SyncBridge     │
│  CryptoService · NotificationService                         │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                      Engine Layer                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │  LocalEngine    │  │  CloudEngine    │  │  ImageEngine │ │
│  │  (GGUF/llama)   │  │ (OpenAI compat) │  │ (Pollinat.) │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │  HfRepository   │  │  EngineManager  │                   │
│  │  (HuggingFace)  │  │ (online/offline)│                   │
│  └─────────────────┘  └─────────────────┘                   │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    Data Layer (SQLite)                        │
│  AppDatabase — 12 tabel: conversations, messages, models,    │
│  planner_posts, messenger_contacts, messenger_messages,      │
│  radio_tracks, users, moderation_queue, announcements,       │
│  donations, code_snippets, comment_agent_log, settings       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔒 Bezpieczeństwo

- **E2E szyfrowanie**: AES-256-GCM dla komunikatora, RSA-2048 wymiana kluczy
- **RBAC**: 4-poziomowy system ról z hashowaniem SHA-256
- **Offline**: tryb bez połączeń = zero danych opuszcza urządzenie
- **Moderacja**: każdy materiał AI trafia do zatwierdzenia
- **Brak telemetrii**: aplikacja nie wysyła żadnych danych analitycznych

---

## 📱 Natywny Android (Kotlin)

- `CwAccessibilityService.kt` — usługa dostępności (drzewo ekranu, gesty, wpisywanie)
- `MainActivity.kt` — mosty MethodChannel: `cw/accessibility`, `cw/files` (SAF)
- Kanały powiadomień: `cw_alerts` (priorytetowe), `cw_general` (ogólne)

---

## 📄 Licencja

Projekt autorski. Wszelkie prawa zastrzeżone.
