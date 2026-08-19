#!/usr/bin/env bash
# ================================================================
# Skrypt kompilacji APK aplikacji Czarne Wilki Prawdy — Wszyscy Won!
# ================================================================
#
# Wymagania:
#   - Flutter SDK >= 3.3.0 (https://docs.flutter.dev/get-started/install)
#   - Android SDK z API 35, Build Tools 35.0.0
#   - JDK 17 (openjdk-17-jdk-headless)
#   - NDK (do biblioteki llama.cpp)
#
# Użycie:
#   # Debug APK (bez podpisu):
#   ./tools/build_apk.sh debug
#
#   # Release APK (wymaga android/key.properties):
#   ./tools/build_apk.sh release
#
#   # Release split per ABI:
#   ./tools/build_apk.sh release-split
#
# Wynikowe pliki:
#   build/app/outputs/flutter-apk/app-debug.apk
#   build/app/outputs/flutter-apk/app-release.apk
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

MODE="${1:-debug}"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  CZARNE WILKI PRAWDY — Kompilacja APK ($MODE)          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo

# Sprawdź Flutter
if ! command -v flutter &>/dev/null; then
  echo "❌ Flutter SDK nie znaleziony. Zainstaluj: https://docs.flutter.dev/get-started/install"
  exit 1
fi

# Sprawdź Java
if ! command -v java &>/dev/null; then
  echo "❌ JDK nie znaleziony. Zainstaluj: sudo apt install openjdk-17-jdk-headless"
  exit 1
fi

echo "Flutter: $(flutter --version | head -1)"
echo "Java:    $(java -version 2>&1 | head -1)"
echo

# Pobierz zależności
echo "📦 Pobieranie zależności..."
flutter pub get

# Sprawdź analizę kodu
echo "🔍 Analiza kodu..."
flutter analyze --no-fatal-infos --no-fatal-warnings || true

case "$MODE" in
  debug)
    echo "🔨 Budowanie APK (debug)..."
    flutter build apk --debug
    APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
    ;;
  release)
    echo "🔨 Budowanie APK (release)..."
    flutter build apk --release
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    ;;
  release-split)
    echo "🔨 Budowanie APK (release, split per ABI)..."
    flutter build apk --release --split-per-abi
    APK_PATH="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
    ;;
  *)
    echo "❌ Nieznany tryb: $MODE (użyj: debug, release, release-split)"
    exit 1
    ;;
esac

if [ -f "$APK_PATH" ]; then
  SIZE=$(du -h "$APK_PATH" | cut -f1)
  echo
  echo "✅ APK gotowy: $APK_PATH ($SIZE)"
  echo
  echo "Zainstaluj na urządzeniu:"
  echo "  adb install $APK_PATH"
else
  echo "❌ APK nie został wygenerowany."
  exit 1
fi
