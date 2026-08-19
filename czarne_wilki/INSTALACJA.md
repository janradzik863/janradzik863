# 🐺 CZARNE WILKI PRAWDY — INSTRUKCJA KOMPILACJI I INSTALACJI

## ⚡ Najszybsza metoda: Docker (ZERO instalacji)

Wystarczy mieć zainstalowanego Dockera. Jedno polecenie buduje APK + Desktop:

```bash
cd czarne_wilki
docker build -f Dockerfile.build -t czarne-wilki-build .
docker run --rm -v "$(pwd)/gotowe:/output" czarne-wilki-build
```

Po zakończeniu (ok. 10–15 minut) w katalogu `./gotowe/` znajdziesz:
- `app-debug.apk` — APK do testów
- `app-release.apk` — APK gotowy do instalacji na telefonie
- `czarne-wilki-linux-x64.tar.gz` — Desktop Linux

---

## 🔧 Metoda ręczna: Skrypt BUDUJ.sh

```bash
cd czarne_wilki
chmod +x BUDUJ.sh
./BUDUJ.sh
```

Skrypt sam sprawdzi wymagania, pobierze brakujące narzędzia i skompiluje wszystko.

---

## 📋 Metoda manualna: krok po kroku

### 1. Zainstaluj wymagania

**Ubuntu/Debian:**
```bash
# JDK 17
sudo apt install openjdk-17-jdk-headless

# Flutter SDK
git clone -b stable https://github.com/flutter/flutter.git ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
flutter doctor

# Android SDK (jeśli brak Android Studio)
mkdir -p ~/android-sdk/cmdline-tools
curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o cmdline-tools.zip
unzip cmdline-tools.zip -d ~/android-sdk/cmdline-tools/latest
echo 'export ANDROID_HOME="$HOME/android-sdk"' >> ~/.bashrc
echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Akceptacja licencji + platformy
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

# Desktop Linux (dodatkowe)
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
flutter config --enable-linux-desktop
```

**macOS:**
```bash
brew install openjdk@17
# Flutter: https://docs.flutter.dev/get-started/install/macos
# Android Studio: https://developer.android.com/studio
```

**Windows:**
```
1. Zainstaluj JDK 17: https://adoptium.net/
2. Zainstaluj Flutter: https://docs.flutter.dev/get-started/install/windows
3. Zainstaluj Android Studio: https://developer.android.com/studio
```

### 2. Pobierz kod i zbuduj

```bash
git clone https://github.com/janradzik863/janradzik863.git
cd janradzik863/czarne_wilki

# Zależności
flutter pub get

# APK Android (debug)
flutter build apk --debug

# APK Android (release)
flutter build apk --release

# Desktop Linux
flutter build linux --release
```

### 3. Gotowe pliki

| Plik | Ścieżka |
|------|---------|
| APK debug | `build/app/outputs/flutter-apk/app-debug.apk` |
| APK release | `build/app/outputs/flutter-apk/app-release.apk` |
| Linux x64 | `build/linux/x64/release/bundle/czarne_wilki` |

---

## 📱 Instalacja APK na telefonie

1. Prześlij plik `.apk` na telefon (kabel USB, Bluetooth, lub link)
2. Na telefonie: **Ustawienia → Bezpieczeństwo → Zezwól na instalację z nieznanych źródeł**
3. Otwórz pobrany plik APK → **Zainstaluj**
4. Uruchom **Czarne Wilki**

### Jeśli Android blokuje instalację:
1. **Ustawienia → Aplikacje → Czarne Wilki** (lub menedżer plików)
2. Menu ⋮ → **Zezwalaj na ograniczone ustawienia**
3. Wróć i zainstaluj ponownie

### Włączenie automatyzacji ekranu:
1. W aplikacji: **Automatyzacja → Włącz usługę dostępności**
2. Lub ręcznie: **Ustawienia → Dostępność → Czarne Wilki — Sterowanie Ekranem → Włącz**

---

## 🖥️ Instalacja na Linux

```bash
tar xzf czarne-wilki-linux-x64.tar.gz -C ~/czarne-wilki
cd ~/czarne-wilki
./czarne_wilki
```

---

## 🔑 Konfiguracja AI (darmowa)

1. Wejdź na [OpenRouter.ai](https://openrouter.ai) i załóż darmowe konto
2. Wygeneruj darmowy klucz API
3. W aplikacji: **Ustawienia → Tryb Sieciowy**
4. **Modele → Dodaj model chmurowy**:
   - Base URL: `https://openrouter.ai/api/v1`
   - API Key: (wklej klucz)
   - Model: `openai/gpt-4o-mini` (lub dowolny darmowy)

### Tryb Offline (100% na urządzeniu):
1. **Modele → Pobierz model GGUF** z HuggingFace
2. **Ustawienia → Tryb Offline**
3. Brak potrzeby internetu — model działa lokalnie

---

## 🐺 CZARNE WILKI PRAWDY — WSZYSCY WON!
