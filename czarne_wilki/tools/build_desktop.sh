#!/usr/bin/env bash
# ================================================================
# Skrypt kompilacji wersji desktopowej aplikacji Czarne Wilki Prawdy
# ================================================================
#
# Obsługiwane platformy:
#   - Linux (x64)     → plik wykonywalny ELF
#   - Windows (x64)   → plik .exe (wymaga cross-compilation lub MSYS2)
#   - macOS (x64/arm) → plik .app
#
# Wymagania (Linux):
#   - Flutter SDK >= 3.3.0
#   - clang, cmake, ninja-build, pkg-config
#   - libgtk-3-dev, liblzma-dev, libstdc++-12-dev
#
# Użycie:
#   ./tools/build_desktop.sh [linux|windows|macos] [debug|release]
#
# Wynikowe pliki (Linux release):
#   build/linux/x64/release/bundle/czarne_wilki
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

PLATFORM="${1:-linux}"
MODE="${2:-release}"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  CZARNE WILKI PRAWDY — Desktop ($PLATFORM $MODE)       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo

# Sprawdź Flutter
if ! command -v flutter &>/dev/null; then
  echo "❌ Flutter SDK nie znaleziony."
  exit 1
fi

# Włącz obsługę desktopa
flutter config --enable-linux-desktop 2>/dev/null || true
flutter config --enable-windows-desktop 2>/dev/null || true
flutter config --enable-macos-desktop 2>/dev/null || true

# Sprawdź zależności systemowe (Linux)
if [ "$PLATFORM" = "linux" ]; then
  for pkg in clang cmake ninja-build pkg-config; do
    if ! command -v "$pkg" &>/dev/null; then
      echo "⚠️  Brak: $pkg — zainstaluj: sudo apt install $pkg"
    fi
  done
fi

echo "📦 Pobieranie zależności..."
flutter pub get

echo "🔨 Budowanie ($PLATFORM, $MODE)..."
case "$MODE" in
  debug)
    flutter build "$PLATFORM" --debug
    ;;
  release)
    flutter build "$PLATFORM" --release
    ;;
  *)
    echo "❌ Nieznany tryb: $MODE"
    exit 1
    ;;
esac

case "$PLATFORM" in
  linux)
    BUNDLE="build/linux/x64/$MODE/bundle"
    if [ -d "$BUNDLE" ]; then
      SIZE=$(du -sh "$BUNDLE" | cut -f1)
      echo
      echo "✅ Desktop Linux gotowy: $BUNDLE ($SIZE)"
      echo
      echo "Uruchom:"
      echo "  $BUNDLE/czarne_wilki"
    fi
    ;;
  windows)
    echo "✅ Desktop Windows — sprawdź build/windows/x64/$MODE/"
    ;;
  macos)
    echo "✅ Desktop macOS — sprawdź build/macos/Build/Products/"
    ;;
esac
