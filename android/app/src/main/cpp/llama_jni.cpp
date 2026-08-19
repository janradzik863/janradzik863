// JNI bridge: Dart/Kotlin <-> llama.cpp (wymaganie #4, #19).
//
// Implementuje natywne metody zadeklarowane w NativeLlmEngine.kt.
// Wymaga źródeł llama.cpp (patrz README.md w tym katalogu).
#include <jni.h>
#include <string>
#include <vector>
#include <atomic>
#include <mutex>

#include "llama.h"

static llama_model*  g_model   = nullptr;
static llama_context* g_ctx   = nullptr;
static std::atomic<bool> g_stop{false};
static std::mutex g_mutex;

// Konwersja tekstu na tokeny i generacja z użyciem natywnego szablonu czatu.
static std::string generate(const std::string& prompt) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (!g_ctx) return "";

    g_stop = false;

    // Tokenizacja promptu.
    std::vector<llama_token> tokens =
        llama_tokenize(g_model, prompt, true, false);

    std::string output;
    const int n_ctx = llama_n_ctx(g_ctx);

    // Pętla generowania (bez autozatrzymywania — stop wyłącznie przez nativeStop).
    while (!g_stop.load() && (int)tokens.size() < n_ctx) {
        if (llama_decode(g_ctx,
                         llama_batch_get_one(tokens.data(),
                                             (int)tokens.size() - 1,
                                             0)) != 0) {
            break;
        }
        const llama_token next = llama_sampler_sample(
            llama_sampler_init_greedy(), g_ctx, -1);
        if (llama_token_is_eog(g_model, next)) break;
        output += llama_token_to_piece(g_model, next);
        tokens.push_back(next);
    }

    // cleanup samplera
    return output;
}

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_czarnewilki_prawdy_NativeLlmEngine_nativeLoad(
        JNIEnv* env, jobject thiz, jstring jpath,
        jint contextSize, jint gpuLayers) {
    const char* cpath = env->GetStringUTFChars(jpath, nullptr);
    std::string path(cpath);
    env->ReleaseStringUTFChars(jpath, cpath);

    llama_backend_init();

    llama_model_params mp = llama_model_default_params();
    mp.n_gpu_layers = gpuLayers; // -1 = auto (Vulkan/Metal)

    llama_context_params cp = llama_context_default_params();
    cp.n_ctx = contextSize;
    cp.n_batch = 512;

    g_model = llama_load_model_from_file(path.c_str(), mp);
    if (!g_model) {
        llama_backend_free();
        return JNI_FALSE;
    }
    g_ctx = llama_new_context_with_model(g_model, cp);
    if (!g_ctx) {
        llama_free_model(g_model);
        g_model = nullptr;
        llama_backend_free();
        return JNI_FALSE;
    }
    return JNI_TRUE;
}

JNIEXPORT jstring JNICALL
Java_com_czarnewilki_prawdy_NativeLlmEngine_nativeGenerate(
        JNIEnv* env, jobject thiz, jstring jprompt) {
    const char* cprompt = env->GetStringUTFChars(jprompt, nullptr);
    std::string prompt(cprompt);
    env->ReleaseStringUTFChars(jprompt, cprompt);

    const std::string out = generate(prompt);
    return env->NewStringUTF(out.c_str());
}

JNIEXPORT void JNICALL
Java_com_czarnewilki_prawdy_NativeLlmEngine_nativeStop(
        JNIEnv* env, jobject thiz) {
    g_stop = true;
}

JNIEXPORT void JNICALL
Java_com_czarnewilki_prawdy_NativeLlmEngine_nativeUnload(
        JNIEnv* env, jobject thiz) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_ctx) { llama_free(g_ctx); g_ctx = nullptr; }
    if (g_model) { llama_free_model(g_model); g_model = nullptr; }
    llama_backend_free();
}

} // extern "C"
