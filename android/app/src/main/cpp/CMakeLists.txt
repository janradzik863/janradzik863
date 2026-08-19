cmake_minimum_required(VERSION 3.18)
project(llama_jni LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)

# ---------------------------------------------------------------------------
#  Ścieżka do źródeł llama.cpp (pobierz jako submoduł — patrz README.md):
#    git submodule add https://github.com/ggml-org/llama.cpp.git third_party/llama.cpp
# ---------------------------------------------------------------------------
set(LLAMA_DIR "${CMAKE_SOURCE_DIR}/../../../../third_party/llama.cpp")

add_subdirectory(${LLAMA_DIR} llama.cpp)

# JNI bridge
add_library(llama SHARED llama_jni.cpp)

target_include_directories(llama PRIVATE ${LLAMA_DIR}/include ${LLAMA_DIR}/ggml/include)
target_link_libraries(llama PRIVATE llama llava)

# Android 15/16: wymóg wyrównania stron 16 KB dla bibliotek natywnych (arm64)
target_link_options(llama PRIVATE -Wl,-z,max-page-size=16384)
