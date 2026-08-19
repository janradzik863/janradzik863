# Instrukcja kompilacji — krok po kroku

Ten dokument przeprowadza Cię przez **całą ścieżkę**: od zera (czysta maszyna)
aż do zainstalowanego pliku **APK** na telefonie oraz wersji **desktop**.

> Projekt: **Czarne Wilki Prawdy – Wszyscy Won!** (Flutter + Kotlin, 22 moduły).
> Cały kod jest gotowy. Brakuje tylko środowiska budującego — to robisz tutaj.

---

## 0. Zanim zaczniesz — co będziesz mieć na końcu

| Wynik | Ścieżka |
|---|---|
| APK (universal, wszystkie ABI) | `build/app/outputs/flutter-apk/app-release.apk` |
| APK per ABI (arm64 / arm / x86_64) | `app-arm64-v8a-release.apk` itd. |
| APK debug (do szybkiego testu) | `app-debug.apk` |
| Desktop Linux | `build/linux/x64/release/bundle/` |
| Desktop Windows | `build/windows/x64/runner/Release/` |

Wymagania minimalne urządzenia: **Android 8.0 (API 26)**; zalecane **API 30+**.
Obsługa architektur: ARM64, 32-bit ARM, x86_64. Wyrównanie natywnych bibliotek
**16 KB** (Android 15/16) jest już skonfigurowane.

---

## 1. Zainstaluj JDK 17

Flutter + Gradle wymagają JDK 17 (nowsze, np. 21, też zwykle działa, ale 17 jest
najpewniejsze — trzymaj się go).

### Windows
1. Pobierz **Temurin JDK 17** (darmowe): https://adoptium.net/temurin/releases/?version=17
2. Zainstaluj, **zaznacz opcję „Set JAVA_HOME"** i „Add to PATH".
3. Sprawdź w **nowym** terminalu:
   ```bat
   java -version
   ```
   Powinno pokazać `17.0.x`.

### Linux (Debian/Ubuntu)
```bash
sudo apt-get update
sudo apt-get install -y openjdk-17-jdk-headless
java -version   # -> 17.x
```

### macOS
```bash
brew install --cask temurin@17
# lub pobierz z adoptium.net
java -version
```

---

## 2. Zainstaluj Android SDK (command line tools)

Flutter sam wykryje SDK przez zmienną `ANDROID_HOME`.

### Windows
1. Pobierz „Command line tools only" z:
   https://developer.android.com/studio#command-line-tools-only
2. Rozpakuj do np. `C:\Android\cmdline-tools\latest\` (ważne: podkatalog `latest`).
3. Ustaw zmienne środowiskowe (Ustawienia → System → Informacje → Zaawansowane
   ustawienia systemu → Zmienne środowiskowe):
   ```
   ANDROID_HOME = C:\Android
   ```

### Linux / macOS
```bash
mkdir -p ~/Android/cmdline-tools
cd ~/Android/cmdline-tools
# pobierz wersję commandline-tools-linux-*.zip z developer.android.com
unzip commandline-tools-linux-*.zip
mv cmdline-tools latest   # musisz mieć ~/Android/cmdline-tools/latest/bin
export ANDROID_HOME="$HOME/Android"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

### Zainstaluj wymagane pakiety SDK (wszystkie systemy)
```bash
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;26.3.11579264"
```

> **platform-tools** zawiera `adb` (instalacja APK na telefonie).
> **ndk** jest wymagany, jeśli włączysz lokalną inferencję llama.cpp (krok 6).

---

## 3. Zainstaluj Flutter SDK

### Windows
1. Pobierz stabilny Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Rozpakuj do np. `C:\flutter` (unikaj ścieżek ze spacjami).
3. Dodaj `C:\flutter\bin` do PATH.

### Linux / macOS
```bash
cd ~
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$HOME/flutter/bin:$PATH"
```

### Weryfikacja (wszystkie systemy)
```bash
flutter --version
flutter doctor
```

`flutter doctor` pokaże, czego brakuje. Po zainstalowaniu JDK i Android SDK
powinieneś zobaczyć zielone ✓ przy **Android toolchain**. (Brakujące ✓ przy
Chrome/Visual Studio **nie przeszkadza** w budowaniu APK.)

---

## 4. Sklonuj i przygotuj projekt

```bash
git clone https://github.com/janradzik863/janradzik863.git
cd janradzik863
git checkout arena/01a01b59-janradzik863   # gałąź robocza (jeśli jest w origin)

flutter pub get
```

### 4a. (OPCJONALNIE) Włącz lokalną inferencję — llama.cpp

Bez tego APK **kompiluje się i działa**; tryb offline po prostu zgłosi
„model niedostępny". Aby mieć pełną inferencję na urządzeniu:

```bash
git submodule add https://github.com/ggml-org/llama.cpp.git third_party/llama.cpp
```

Następnie **odkomentuj** sekcję `externalNativeBuild` w pliku
`android/app/build.gradle` (jest oznaczona komentarzem). NDK skompiluje
`libllama.so` automatycznie.

---

## 5. Podpisywanie (wymagane dla release)

Android przyjmuje aktualizacje tylko podpisane **tym samym kluczem**. Wygeneruj
go **raz** i **bezpiecznie przechowaj** (utrata klucza = utrata możliwości
aktualizacji).

### 5a. Wygeneruj keystore
```bash
keytool -genkey -v \
  -keystore release.keystore \
  -alias czarnewilki \
  -keyalg RSA -keysize 2048 -validity 10000
```
(keytool jest w bin JDK; odpowiesz na pytania o nazwę/organizację/hasło)

### 5b. Utwórz `android/key.properties`
```bash
cp android/key.properties.example android/key.properties
```
Edytuj `android/key.properties` i wpisz **swoje** wartości:
```
storePassword=TWOJE_HASLO
keyPassword=TWOJE_HASLO
keyAlias=czarnewilki
storeFile=../release.keystore
```
(przenieś `release.keystore` do katalogu `android/`, tak by ścieżka się zgadzała)

> ⚠️ Nigdy nie commit'uj `key.properties` ani `*.keystore` — są w `.gitignore`.

---

## 6. Zbuduj APK

### Szybki test (debug, bez klucza)
```bash
flutter build apk --debug
# -> build/app/outputs/flutter-apk/app-debug.apk
```

### Produkcja (release, podpisany)
```bash
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk   (universal, wszystkie ABI)
```

### Warianty per ABI (mniejsze pliki)
```bash
flutter build apk --release --split-per-abi
# -> app-arm64-v8a-release.apk   (większość nowoczesnych telefonów, Snapdragon)
# -> app-armeabi-v7a-release.apk (starsze, 32-bit)
# -> app-x86_64-release.apk      (emulatory)
```

> Skrót: `./build.sh` robi to samo (wykrywa klucz, buduje release + split + desktop).

---

## 7. Zainstaluj APK na telefonie

1. Na telefonie włącz **Opcje programisty**:
   Ustawienia → Informacje o telefonie → stuknij 7× w „Numer kompilacji".
2. Włącz **Debugowanie USB** (Opcje programisty).
3. Podłącz telefon kablem USB i potwierdź autoryzację.
4. Sprawdź, czy jest widoczny:
   ```bash
   adb devices
   ```
5. Zainstaluj:
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```
   (dla split-ABI użyj `app-arm64-v8a-release.apk`)

Alternatywnie skopiuj APK na telefon (e-mail/Dysk/Android File Transfer) i
otwórz — Android zapyta o zgodę na instalację z nieznanego źródła.

---

## 8. Zbuduj wersję desktop

### Linux
```bash
sudo apt-get install -y clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev
flutter build linux --release
# -> build/linux/x64/release/bundle/czarne_wilki_prawdy
```

### Windows
```bash
flutter build windows --release
# -> build/windows/x64/runner/Release/czarne_wilki_prawdy.exe
```

### macOS (opcjonalnie)
```bash
flutter build macos --release
```

---

## 9. Pierwsze uruchomienie i konfiguracja

1. Zainstaluj APK i otwórz **Czarne Wilki Prawdy**.
2. **Darmowy model AI** (OpenRouter):
   - Załóż konto na https://openrouter.ai → wygeneruj klucz API.
   - W aplikacji: **Ustawienia → Dostawca AI** → chip „OpenRouter" → wklej klucz.
   - Model: `openai/gpt-oss-120b:free` (lub inny darmowy).
3. **DeepSeek** (opcjonalnie): klucz z https://platform.deepseek.com →
   chip „DeepSeek" → model `deepseek-chat`.
4. **Sterowanie ekranem** (agent automatyzacji):
   Ustawienia → Dostępność → **„Czarne Wilki — sterowanie ekranem"** → Włącz.
   Jeśli Android blokuje („Ograniczone ustawienia"):
   Ustawienia → Aplikacje → Czarne Wilki Prawdy → ⋮ → „Zezwalaj na ograniczone ustawienia".
5. **Telegram** (zdalny dostęp): token od @BotFather → Ustawienia → Telegram.

---

## 10. Najczęstsze problemy (rozwiązywanie)

| Problem | Rozwiązanie |
|---|---|
| `flutter doctor` nie widzi Androida | ustaw `ANDROID_HOME` i uruchom `flutter doctor --android-licenses` |
| `JAVA_HOME` / „Unsupported class file" | upewnij się, że używasz **JDK 17** |
| `gradle` pobiera się wiecznie | pierwszy build pobiera zależności — daj mu kilka minut; sprawdź internet |
| błąd podpisu przy aktualizacji | instalujesz APK podpisany **innym kluczem** — odinstaluj stary lub użyj tego samego keystore |
| `minSdkVersion` / „uses-sdk" | projekt celuje w API 26+; urządzenie musi mieć Android 8.0+ |
| brak `libllama.so` | nie skompilowano natywnego silnika — patrz krok 4a (aplikacja i tak działa) |
| desktop się nie buduje | brakuje zależności GTK (Linux) — patrz krok 8 |

---

## 11. Pliki wynikowe — pełna lista

Po udanym buildzie `./build.sh` otrzymujesz:
```
build/app/outputs/flutter-apk/
├── app-release.apk            ← instaluj ten (universal)
├── app-arm64-v8a-release.apk  ← Snapdragon / nowoczesne
├── app-armeabi-v7a-release.apk
└── app-x86_64-release.apk
build/linux/x64/release/bundle/   ← desktop Linux
```
