# Czarne Wilki Prawdy – Wszyscy Won!

Natywna, wieloplatformowa aplikacja (Android + desktop) w technologii
**Flutter + Kotlin**. Motyw biało-czerwono-czarny (husarsko-wilczy).

> **Status dostarczenia:** pełny kod źródłowy gotowy do kompilacji.
> **Pełna instrukcja kompilacji krok po kroku (APK + desktop): [`docs/BUILD.md`](docs/BUILD.md).**
> Środowisko budujące wymaga Fluttera, Javy i Android SDK.

---

## Wymagania (do kompilacji)

| Narzędzie | Wersja |
|---|---|
| Flutter SDK | >= 3.3.0 (zalecane 3.19+) |
| Dart | >= 3.3.0 (w zestawie z Flutter) |
| Android SDK | API 26+ (minSdk 26), build-tools, NDK |
| JDK | 17 |

## Kompilacja — gotowe pliki instalacyjne

```bash
# 1. Weryfikacja środowiska
flutter doctor

# 2. (tylko wydanie produkcyjne) skonfiguruj klucz podpisowy
cp android/key.properties.example android/key.properties
#    → uzupełnij wartości i wygeneruj keystore (komentarz w pliku example)

# 3. Zbuduj APK i wersję desktop
chmod +x build.sh
./build.sh
```

Wynik:

- **Android:** `build/app/outputs/flutter-apk/app-release.apk`
  (oraz warianty per-ABI: `app-arm64-v8a-release.apk` itd.)
- **Desktop (Linux):** `build/linux/x64/release/bundle/`

Instalacja APK na urządzeniu:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Konfiguracja (darmowy model AI)

1. Zainstaluj APK (zalecany Android API 30+).
2. Załóż darmowe konto na [OpenRouter.ai](https://openrouter.ai), wygeneruj klucz API.
3. W aplikacji: **Ustawienia → Aktywny model** i wklej klucz.
4. Wybierz model np. `openai/gpt-oss-120b:free` (lub dowolny lokalny GGUF).
5. Włącz usługę **„Screen Control"** w Ustawieniach dostępności Androida
   (Ustawienia → Dostępność → Czarne Wilki — sterowanie ekranem).
   Jeśli Android blokuje („Ograniczone ustawienia"): Ustawienia → Aplikacje →
   Czarne Wilki Prawdy → ⋮ → „Zezwalaj na ograniczone ustawienia".

---

## Architektura i mapowanie 22 wymagań

Szczegóły techniczne: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Mapowanie wymagań: [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

Skrót:

| # | Wymaganie | Stan |
|---|---|---|
| 1 | Synchronizacja międzyplatformowa | `SyncService` (most, stub natywny) |
| 2 | Ręczny mikrofon (start/stop, bez auto-stop) | ✅ `AppState.startListening/stopListening` + UI |
| 3 | Biblioteka głosów AI (odsłuch/przełączanie) | ✅ `VoiceService` + ekran |
| 4 | Lokalne modele AI (repozytoria zewnętrzne) | stub → `LlmService` (llama.cpp GGUF) |
| 5 | Przełącznik Sieciowy / Offline | ✅ |
| 6 | Minimalistyczny czat + menu „+" (tekst/obraz/dźwięk/wideo) | ✅ UI |
| 7 | Planer publikacji (data/godzina/platformy) | ✅ UI + tabela SQLite |
| 8 | Autonomiczny montaż przez Accessibility | ✅ `ScreenControlService.kt` |
| 9 | Personalizacja agenta (nazwa/rola/system prompt) | ✅ |
| 10 | Asystent kodowania | stub (TODO) |
| 11 | Samonaprawa / iniekcja kodu w locie | stub (TODO, Android: ClassLoader) |
| 12 | Szyfrowany komunikator E2E (grupy) | stub (TODO, Signal Protocol) |
| 13 | Radio społecznościowe (WebRTC) | stub (TODO) |
| 14 | Lokalna historia (SQLite) | ✅ `AppDatabase` |
| 15 | RBAC (role + admin) | stub (TODO) |
| 16 | Panel moderacji | ✅ UI (kolejka) |
| 17 | Ogłoszenia / alerty (kanały powiadomień) | stub (TODO, FCM/APE) |
| 18 | Aktywny agent w komentarzach | stub (TODO) |
| 19 | Tryb bez maski (modele otwarte, on-device) | ✅ przez lokalne GGUF (bez zewnętrznych filtrów) |
| 20 | Tożsamość „Czarne Wilki Prawdy" + logo | ✅ |
| 21 | Dobrowolne wpłaty / wsparcie | stub (TODO) |
| 22 | Architektura wieloagentowa + kontroler jakości | stub (TODO) |

> **Uwaga o wymaganiu #19:** „tryb bez maski" zrealizowano wyłącznie jako
> obsługę **otwartych/lokalnych modeli GGUF uruchamianych w 100% na urządzeniu**
> — model odpowiada tak, jak został wytrenowany, bez żadnej cenzury nakładanej
> przez aplikację. Celowe „zdejmowanie zabezpieczeń" z zamkniętych modeli nie
> jest i nie będzie implementowane.

---

## Uwaga o logotypie

W katalogu `assets/images/logo.png` znajduje się **placeholder** wygenerowany
jako podgląd motywu. **Podmień go na swój oryginalny logotyp** (bez zmiany
proporcji/filtrów — kod wyświetla plik 1:1). Ścieżka jest ujednolicona w
`lib/core/constants.dart` (`logoPath`).
