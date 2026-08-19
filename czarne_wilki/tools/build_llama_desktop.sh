#!/usr/bin/env bash
#
# Buduje bibliotekę llama.cpp dla DESKTOPU (Linux; dla Windows patrz
# instrukcja na końcu) i podpowiada, gdzie ją umieścić, aby aplikacja
# Czarne Wilki uruchamiała lokalne modele GGUF.
#
# Użycie:  ./tools/build_llama_desktop.sh [--install]
#
set -euo pipefail

command -v cmake >/dev/null || { echo "Wymagany CMake."; exit 1; }
command -v git >/dev/null || { echo "Wymagany Git."; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/cw-llama-desktop"
BUNDLE="$ROOT/build/linux/x64/release/bundle/lib"

rm -rf "$WORK"
mkdir -p "$WORK"

echo "→ Pobieranie llama.cpp…"
git clone --depth 1 https://github.com/ggml-org/llama.cpp "$WORK/llama.cpp"

echo "→ Konfiguracja i kompilacja (Release, host)…"
cmake -S "$WORK/llama.cpp" -B "$WORK/build" -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_CURL=OFF \
  -DGGML_CUDA=OFF
cmake --build "$WORK/build" --target llama -j "$(nproc 2>/dev/null || sysctl -n hw.ncpu)"

LIB="$(find "$WORK/build" -name 'libllama.so' | head -n 1)"
[ -n "$LIB" ] || { echo "Nie znaleziono libllama.so."; exit 1; }

if [ "${1:-}" = "--install" ] && [ -d "$BUNDLE" ]; then
  cp "$LIB" "$BUNDLE/libllama.so"
  echo "OK → zainstalowano w $BUNDLE/libllama.so"
  echo "Uruchom aplikację normalnie (build/linux/x64/release/bundle/)."
else
  cp "$LIB" "$ROOT/libllama.so"
  cat <<EOF
OK → $ROOT/libllama.so

Gdzie umieścić bibliotekę:
  a) Do bundle aplikacji:   cp libllama.so build/linux/x64/release/bundle/lib/
  b) Albo z LD_LIBRARY_PATH: LD_LIBRARY_PATH=. build/linux/x64/release/bundle/czarne_wilki

WINDOWS (MSVC / Developer PowerShell):
  git clone --depth 1 https://github.com/ggml-org/llama.cpp
  cmake -S llama.cpp -B build -DLLAMA_BUILD_TESTS=OFF -DLLAMA_CURL=OFF
  cmake --build build --config Release --target llama
  # libllama.dll → build/windows/x64/runner/Release/ (obok czarne_wilki.exe)
EOF
fi
