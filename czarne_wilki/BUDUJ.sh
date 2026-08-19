#!/usr/bin/env bash
# ================================================================
#  🐺 CZARNE WILKI PRAWDY — WSZYSCY WON!
#  AUTOMATYCZNA KOMPILACJA — JEDNO POLECENIE
# ================================================================
#
#  Ten skrypt:
#   1. Sprawdza wymagania (Flutter, JDK, Android SDK)
#   2. Pobiera brakujące narzędzia
#   3. Kompiluje APK (debug + release)
#   4. Kompiluje Desktop Linux
#   5. Kopiuje gotowe pliki do katalogu ./gotowe/
#
#  UŻYCIE:
#    chmod +x BUDUJ.sh
#    ./BUDUJ.sh
#
#  LUB PRZEZ DOCKER (zero instalacji):
#    docker build -f Dockerfile.build -t cw-build .
#    docker run --rm -v "$(pwd)/gotowe:/output" cw-build
#
# ================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
NC='\033[0m'

banner() {
  echo
  echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║${WHITE}  🐺 CZARNE WILKI PRAWDY — WSZYSCY WON!                  ${RED}║${NC}"
  echo -e "${RED}║${WHITE}  Automatyczna kompilacja APK + Desktop                   ${RED}║${NC}"
  echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
  echo
}

ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
step() { echo -e "\n${WHITE}━━━ $1 ━━━${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
OUTPUT_DIR="$SCRIPT_DIR/gotowe"
mkdir -p "$OUTPUT_DIR"

banner

# ─── Sprawdź wymagania ───────────────────────────────────────

step "KROK 1: Sprawdzanie wymagań"

# Flutter
if command -v flutter &>/dev/null; then
  FLUTTER_VER=$(flutter --version 2>&1 | head -1)
  ok "Flutter: $FLUTTER_VER"
else
  warn "Flutter nie znaleziony."
  echo "  Instalacja: https://docs.flutter.dev/get-started/install"
  echo "  Lub: git clone -b stable https://github.com/flutter/flutter.git ~/flutter"
  echo "  Dodaj do PATH: export PATH=\"\$HOME/flutter/bin:\$PATH\""
  echo
  
  read -p "Chcesz, żebym zainstalował Flutter automatycznie? [T/n] " -r
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Pobieranie Flutter SDK..."
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter_sdk"
    export PATH="$HOME/flutter_sdk/bin:$PATH"
    flutter --version
    ok "Flutter zainstalowany"
  else
    fail "Flutter jest wymagany do kompilacji."
  fi
fi

# Java
if command -v java &>/dev/null && command -v javac &>/dev/null; then
  JAVA_VER=$(java -version 2>&1 | head -1)
  ok "Java: $JAVA_VER"
else
  warn "JDK nie znaleziony."
  echo "  Instalacja: sudo apt install openjdk-17-jdk-headless"
  echo "  Lub: brew install openjdk@17 (macOS)"
  fail "JDK 17 jest wymagany do kompilacji Android."
fi

# Android SDK
if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
  ok "Android SDK: $ANDROID_HOME"
else
  warn "ANDROID_HOME nie ustawiony."
  if [ -d "$HOME/Android/Sdk" ]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
    ok "Znaleziono Android SDK: $ANDROID_HOME"
  elif [ -d "/opt/android-sdk" ]; then
    export ANDROID_HOME="/opt/android-sdk"
    ok "Znaleziono Android SDK: $ANDROID_HOME"
  else
    echo "  Zainstaluj Android SDK lub ustaw ANDROID_HOME."
    echo "  Szybka instalacja:"
    echo "    mkdir -p ~/android-sdk/cmdline-tools"
    echo "    curl -O https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    echo "    unzip commandlinetools*.zip -d ~/android-sdk/cmdline-tools/latest"
    echo "    export ANDROID_HOME=~/android-sdk"
    fail "Android SDK jest wymagany."
  fi
fi

# ─── Zależności Flutter ──────────────────────────────────────

step "KROK 2: Pobieranie zależności"
flutter pub get
ok "Zależności pobrane"

# ─── Kompilacja APK ─────────────────────────────────────────

step "KROK 3: Kompilacja APK (debug)"
flutter build apk --debug
cp build/app/outputs/flutter-apk/app-debug.apk "$OUTPUT_DIR/CzarneWilki-debug.apk"
ok "APK debug: $OUTPUT_DIR/CzarneWilki-debug.apk"

step "KROK 4: Kompilacja APK (release)"
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "$OUTPUT_DIR/CzarneWilki-release.apk"
ok "APK release: $OUTPUT_DIR/CzarneWilki-release.apk"

step "KROK 5: Kompilacja APK (split per ABI)"
flutter build apk --release --split-per-abi
for apk in build/app/outputs/flutter-apk/*-release.apk; do
  NAME=$(basename "$apk" | sed 's/app-/CzarneWilki-/')
  cp "$apk" "$OUTPUT_DIR/$NAME"
  ok "APK: $OUTPUT_DIR/$NAME"
done

# ─── Kompilacja Desktop ─────────────────────────────────────

step "KROK 6: Kompilacja Desktop Linux"
if [[ "$(uname -s)" == "Linux" ]]; then
  flutter config --enable-linux-desktop 2>/dev/null || true
  
  # Sprawdź zależności desktopa
  MISSING=""
  for pkg in clang cmake ninja-build; do
    if ! command -v "$pkg" &>/dev/null; then
      MISSING="$MISSING $pkg"
    fi
  done
  
  if [ -n "$MISSING" ]; then
    warn "Brakuje pakietów:$MISSING"
    echo "  Zainstaluj: sudo apt install$MISSING pkg-config libgtk-3-dev liblzma-dev"
    echo "  Pomijam kompilację desktop."
  else
    flutter build linux --release
    cd build/linux/x64/release/bundle
    tar czf "$OUTPUT_DIR/CzarneWilki-linux-x64.tar.gz" .
    cd "$SCRIPT_DIR"
    ok "Desktop Linux: $OUTPUT_DIR/CzarneWilki-linux-x64.tar.gz"
  fi
else
  warn "Kompilacja Linux wymaga systemu Linux. Pomijam."
fi

# ─── Podsumowanie ────────────────────────────────────────────

echo
echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║${GREEN}  ✅ KOMPILACJA ZAKOŃCZONA SUKCESEM!                      ${RED}║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${WHITE}Gotowe pliki do pobrania i instalacji:${NC}"
echo
ls -lh "$OUTPUT_DIR/"
echo
echo -e "${WHITE}📱 Android:${NC} Prześlij plik .apk na telefon i zainstaluj."
echo -e "${WHITE}🖥️  Linux:${NC}   Rozpakuj tar.gz i uruchom ./czarne_wilki"
echo
echo -e "${RED}🐺 CZARNE WILKI PRAWDY — WSZYSCY WON! 🐺${NC}"
