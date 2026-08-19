# Lokalny silnik inferencji (llama.cpp) — wymaganie #4 / #19

Ten katalog zawiera most JNI (`llama_jni.cpp`) i konfigurację CMake
łączącą aplikację z silnikiem **llama.cpp** (GPU: Vulkan / Metal / NEON).

## Jak włączyć lokalną inferencję (build z natywnym silnikiem)

1. Dodaj llama.cpp jako submoduł (z katalogu głównego repo):

   ```bash
   git submodule add https://github.com/ggml-org/llama.cpp.git third_party/llama.cpp
   ```

2. Odkomentuj sekcję `externalNativeBuild` w `android/app/build.gradle`.

3. Zbuduj APK (NDK skompiluje `libllama.so` dla ABI z listy `abiFilters`):

   ```bash
   ./build.sh
   ```

4. Umieść model `.gguf` (np. `qwen2.5-1.5b-instruct-q4_k_m.gguf`) w katalogu
   aplikacji (pobierz przez ekran „Modele" w ustawieniach — `ModelRepository`).

## Uwagi

- Bez `third_party/llama.cpp` aplikacja **nadal się kompiluje i działa** —
  silnik zgłosi wtedy status `unavailable`, a tryb offline wyświetli
  odpowiedni komunikat (brak crashu).
- `NativeLlmEngine.kt` ładuje bibliotekę leniwie i łapie
  `UnsatisfiedLinkError`, więc brak natywnej lib nie przerywa działania.
- Wyrównanie 16 KB (`max-page-size=16384`) jest wymagane dla Android 15/16.
