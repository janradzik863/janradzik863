#!/usr/bin/env bash
#
# Podmienia logotyp projektu na oryginalny plik użytkownika i regeneruje
# wszystkie ikony aplikacji. Oryginalna grafika jest kopiowana 1:1
# (bez filtrów i modyfikacji); ikony powstają wyłącznie przez skalowanie.
#
# Użycie:  ./tools/make_icons.sh /ścieżka/do/logo.jpeg
#
set -euo pipefail

LOGO="${1:?Podaj ścieżkę do pliku logo, np. ./tools/make_icons.sh logo.jpeg}"
command -v convert >/dev/null || { echo "Wymagany ImageMagick (convert)."; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 1) Oryginał trafia do assetów bez żadnych zmian.
cp "$LOGO" assets/logo/cwp_logo.jpeg

RES="android/app/src/main/res"
mkdir -p "$RES"/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}

# 2) Ikona adaptacyjna: logo w bezpiecznej strefie (66%) na białym tle.
convert assets/logo/cwp_logo.jpeg -resize 285x285 -gravity center \
  -background white -extent 432x432 \
  "$RES/mipmap-xxxhdpi/ic_launcher_foreground_base.png"

# 3) Ikony klasyczne (czysta skala, proporcje zachowane).
for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  dir="${pair%%:*}"; size="${pair##*:}"
  convert assets/logo/cwp_logo.jpeg -resize "${size}x${size}" \
    "$RES/mipmap-$dir/ic_launcher_legacy.png"
done

# 4) Ikona Windows (.ico), jeśli istnieje projekt windows/ (desktop).
if [ -d "windows/runner/resources" ]; then
  convert assets/logo/cwp_logo.jpeg \
    -define icon:auto-resize=256,128,64,48,32,16 \
    windows/runner/resources/app_icon.ico
  echo "OK — windows/runner/resources/app_icon.ico"
fi

echo "OK — logo podmienione, ikony zregenerowane."
echo "Przebuduj:  flutter build apk --release  /  flutter build linux|windows"
