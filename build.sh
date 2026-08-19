#!/usr/bin/env bash
# =============================================================================
#  Czarne Wilki Prawdy — skrypt budowania (Android APK + desktop)
#
#  Uruchom na maszynie z zainstalowanym Flutter SDK (>=3.3) i Android SDK.
#  Wyniki:
#    android:  build/app/outputs/flutter-apk/app-release.apk (lub --split-per-abi)
#    desktop:  build/linux/x64/release/bundle/  (oraz Windows wg flagi)
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

echo "==> [1/4] Weryfikacja Fluttera..."
if ! command -v flutter >/dev/null 2>&1; then
  echo "BŁĄD: nie znaleziono 'flutter' w PATH. Zainstaluj Flutter: https://docs.flutter.dev/get-started/install"
  exit 1
fi
flutter --version

echo "==> [2/4] Pobieranie zależności..."
flutter pub get

echo "==> [3/4] Sprawdzanie klucza podpisowego..."
if [ ! -f android/key.properties ]; then
  echo "UWAGA: brak android/key.properties. Tworzę tymczasowy klucz debug dla podglądu."
  echo "Dla wydania produkcyjnego: cp android/key.properties.example android/key.properties"
  echo "i wygeneruj własny keystore (patrz komentarze w pliku example)."
  # Zbuduj z podpisem debug, żeby coś dało się zainstalować od razu.
  BUILD_MODE="--debug"
else
  BUILD_MODE="--release"
fi

echo "==> [4/4] Generowanie brakujących folderów platform desktopowych..."
if [ ! -d linux ] || [ ! -d windows ]; then
  flutter create --platforms=linux,windows --project-name czarne_wilki_prawdy .
fi

echo "==> Budowanie APK (Android)..."
if [ "$BUILD_MODE" = "--release" ]; then
  flutter build apk --release "$@"
  echo ""
  echo "GOTOWE (universal): build/app/outputs/flutter-apk/app-release.apk"
  flutter build apk --release --split-per-abi "$@"
  echo "GOTOWE (split ABI):  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  echo "                     build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
  echo "                     build/app/outputs/flutter-apk/app-x86_64-release.apk"
else
  flutter build apk --debug "$@"
  echo "GOTOWE (debug): build/app/outputs/flutter-apk/app-debug.apk"
fi

echo ""
echo "==> Budowanie wersji desktop (Linux)..."
flutter build linux --release "$@" || echo "(pomijam desktop — brak zależności GTK; uruchom 'flutter doctor')"

echo ""
echo "Zakończono. Pliki instalacyjne znajdują się w katalogu build/."
