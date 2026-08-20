# Czarne Wilki — prywatny asystent AI

Aplikacja mobilna Android (Flutter + natywny Kotlin) łącząca lokalne
modele AI (GGUF / llama.cpp) z dostawcami chmurowymi (OpenRouter, DeepSeek,
OpenAI), biblioteką głosów, ciągłym nasłuchem mikrofonu i agentem
automatyzacji własnego urządzenia — z jawnym dziennikiem każdej akcji.

**Prywatność:** historia rozmów w SQLite na urządzeniu, klucze API tylko
u wybranego dostawcy, tryb Offline = zero połączeń sieciowych.

---

## Funkcje

| Moduł | Opis |
|---|---|
| Silnik hybrydowy | Modele lokalne GGUF (llama.cpp) lub chmura (OpenAI-compatible) |
| Tryb Sieciowy/Offline | Przełącznik; Offline blokuje wszelkie połączenia |
| Czat | Strumieniowanie, menu „+”: tekst / obraz (Pollinations) / głos |
| Historia | SQLite; każdy nowy model czyta pełną dotychczasową rozmowę |
| Personalizacja | Imię, rola i System Prompt agenta |
| Głosy | Biblioteka TTS z odsłuchem, wyborem, tempem i wysokością |
| Mikrofon | Ciągły nasłuch do ręcznego wciśnięcia „Stop” |
| Automatyzacja | Agent na usłudze dostępności: odczyt drzewa ekranu, stuknięcia, wpisywanie, przewijanie, nawigacja — z polityką działania i dziennikiem akcji |

## Wymagania

- Flutter **3.27+** (stable), Dart ≥ 3.3
- JDK 17, Android SDK (API 35), Android NDK (do libllama.so)
- Desktop: Linux — `clang cmake ninja-build pkg-config libgtk-3-dev`;
  Windows — Visual Studio 2022 z workloadem „Desktop development with C++”
- Urządzenie mobilne: Android 8+ (API 28), ARM64 (do modeli lokalnych)

## Budowa (krok po kroku)

    # 1. Generuje brakujące pliki platformowe: android (gradle wrapper),
    #    linux/ i windows/ (runnery) — zawsze zgodne z Twoją wersją Fluttera
    flutter create . --platforms=android,linux,windows \
      --project-name=czarne_wilki --org app

    # 2. Zależności
    flutter pub get

    # 3. (Opcjonalnie, dla modeli lokalnych) biblioteka llama.cpp:
    ANDROID_NDK_HOME=/ścieżka/do/ndk ./tools/build_llama_android.sh   # Android
    ./tools/build_llama_desktop.sh                                    # Linux

    # 4. Uruchomienie / budowa
    flutter run -d <device-id>
    flutter build apk --release        # → build/app/outputs/flutter-apk/
    flutter build linux --release      # → build/linux/x64/release/bundle/
    flutter build windows --release    # → build/windows/x64/runner/Release/

> Bez kroku 3 aplikacja działa w pełni w trybie chmurowym — ekran Modeli
> pokaże status biblioteki i instrukcję.

## Konfiguracja AI (za darmo)

1. Załóż konto na OpenRouter.ai i wygeneruj klucz API.
2. W aplikacji: **Modele → MODELE CHMUROWE → chip „OpenRouter (darmowe)”**.
3. Wklej klucz; model: `openai/gpt-oss-120b:free` (lub inny darmowy).
4. Zapisz i aktywuj. Gotowe.

DeepSeek: Base URL `https://api.deepseek.com/v1`, model `deepseek-chat`.

## Włączenie automatyzacji

Ustawienia Androida → Dostępność → **Czarne Wilki — Sterowanie Ekranem**.

Jeśli APK instalowany spoza sklepu blokuje ustawienia:
Ustawienia → Aplikacje → Czarne Wilki → menu ⋮ → „Zezwól na ustawienia
ograniczone” → wróć do Dostępności.

Agent wykonuje wyłącznie zadania na Twoim urządzeniu. Nie publikuje,
nie komentuje i nie udaje człowieka wobec innych osób — zasady są
wbudowane w kod (bramka polityki) i w prompt agenta, a każda akcja
trafia do widocznego dziennika.

## Podmiana logo na oryginalne

    ./tools/make_icons.sh /ścieżka/do/cwp_logo.jpeg
    flutter build apk --release

Oryginalny plik jest kopiowany bez modyfikacji; ikony to wyłącznie skale.

## Podpisywanie wydania

    keytool -genkey -v -keystore ~/cw.keystore -alias cw -keyalg RSA \
      -keysize 2048 -validity 10000

Następnie skonfiguruj `signingConfigs.release` w
`android/app/build.gradle.kts`. Nie zmieniaj klucza między wydaniami.

## Znane ograniczenia

- **Ciągły nasłuch:** silnik rozpoznawania Androida sam kończy sesje po
  ciszy — aplikacja automatowo wznawia nasłuch do ręcznego „Stop”
  (krótkie przerwy są nieuniknione, to ograniczenie platformy).
- **Modele lokalne:** wymagają ARM64 + RAM (≈ 1 GB dla 1B Q4, ≈ 4 GB dla
  7-8B Q4). Przy słabszych urządzeniach zmniejsz kontekst.
- **16 KB alignment:** użyj NDK r27+ (skrypt ustawia
  `-Wl,-z,max-page-size=16384`) dla Androida 15/16.
- **llama_cpp_dart ^0.2.2:** cała integracja z pakietem jest w
  `lib/engine/llama_factory_io.dart` — przy zmianie API pakietu
  aktualizujesz jeden plik.
- **file_picker ^8.x:** celowo przypięty do serii 8 (stabilne API).
  Migracja do v12 zmienia sygnatury (`FilePicker.pickFiles` statyczne,
  brak `FilePickerResult`) — dotyczy wyłącznie
  `lib/services/files_service.dart`.

## Struktura

    lib/
      core/         motyw biało-czerwony, polityka automatyzacji
      data/         SQLite (rozmowy, modele, ustawienia), modele danych
      engine/       silniki AI (lokalny/chmura), HF, obrazy
      voice/        TTS (biblioteka głosów), STT (ciągły nasłuch)
      automation/   most dostępności + pętla agenta (ekran→AI→akcja)
      ui/           ekrany: start, czat, modele, głosy, agent, automatyzacja
    android/…/app/czarnewilki/
      MainActivity.kt           most MethodChannel
      CwAccessibilityService.kt drzewo ekranu, gesty, wpisywanie
