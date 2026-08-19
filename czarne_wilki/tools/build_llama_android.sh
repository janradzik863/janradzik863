#!/usr/bin/env bash
#
# Buduje bibliotekę llama.cpp (libllama.so) dla Androida arm64-v8a
# i umieszcza ją w android/app/src/main/jniLibs/arm64-v8a/.
#
# Wymagania:
#   - Android NDK (r27+ zalecane: zgodność z 16 KB page alignment
#     wymaganym przez Androida 15/16)
#   - CMake, Ninja, Git
#
# Użycie:
#   ANDROID_NDK_HOME=/ścieżka/do/ndk ./tools/build_llama_android.sh
#
set -euo pipefail

NDK="${ANDROID_NDK_HOME:?Ustaw ANDROID_NDK_HOME na katalog NDK}"
command -v cmake >/dev/null || { echo "Wymagany CMake."; exit 1; }
command -v ninja >/dev/null || { echo "Wymagany Ninja."; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/cw-llama-build"
OUT="$ROOT/android/app/src/main/jniLibs/arm64-v8a"

mkdir -p "$OUT"
rm -rf "$WORK"
mkdir -p "$WORK"

echo "→ Pobieranie llama.cpp…"
git clone --depth 1 https://github.com/ggml-org/llama.cpp "$WORK/llama.cpp"

echo "→ Konfiguracja CMake (arm64-v8a, Release)…"
cmake -S "$WORK/llama.cpp" -B "$WORK/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-28 \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_CURL=OFF \
  -DGGML_CUDA=OFF \
  -DGGML_OPENMP=OFF \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384"

echo "→ Kompilacja…"
cmake --build "$WORK/build" --target llama -j "$(nproc)"

LIB=$(find "$WORK/build" -name 'libllama.so' | head -n 1)
[ -n "$LIB" ] || { echo "Nie znaleziono libllama.so."; exit 1; }

cp "$LIB" "$OUT/libllama.so"
echo "OK → $OUT/libllama.so"
echo "Sprawdź wyrównanie 16 KB:  llvm-readelf -l $OUT/libllama.so | grep LOAD"
echo "Przebuduj APK:  flutter build apk --release"
