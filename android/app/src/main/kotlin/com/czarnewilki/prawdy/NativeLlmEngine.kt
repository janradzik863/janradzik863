package com.czarnewilki.prawdy

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Natywny silnik lokalnej inferencji LLM (wymaganie #4, #19).
 *
 * Ładuje model GGUF przez JNI do llama.cpp i generuje tokeny w pełni na
 * urządzeniu (bez sieci, bez zewnętrznych filtrów). Odciążenie GPU przez
 * Vulkan, wybór warstw offloadingu na podstawie możliwości urządzenia.
 *
 * Wymaga skompilowania natywnej biblioteki `libllama.so` (patrz
 * `android/app/src/main/cpp/README.md`). Bez niej silnik zgłasza
 * `unavailable` — aplikacja działa normalnie w trybie chmurowym.
 *
 * Uwaga: wyłącznie java.lang/kotlin stdlib + android.os — bez dodatkowych
 * zależności (żadnych coroutines), więc kompiluje się w czystym projekcie.
 */
class NativeLlmEngine(
    private val messenger: io.flutter.plugin.common.BinaryMessenger
) {

    companion object {
        private const val TAG = "NativeLlmEngine"
        private const val CHANNEL = "czarne_wilki/llm"
        private var libAvailable = false

        init {
            libAvailable = try {
                System.loadLibrary("llama")
                true
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "Biblioteka llama.cpp nie jest dostępna: ${e.message}")
                false
            }
        }
    }

    // --- Zewnętrzne metody natywne (implementacja w llama_jni.cpp) ---
    private external fun nativeLoad(path: String, contextSize: Int, gpuLayers: Int): Boolean
    private external fun nativeGenerate(prompt: String): String
    private external fun nativeStop()
    private external fun nativeUnload()

    @Volatile
    private var loaded = false

    private val mainHandler = Handler(Looper.getMainLooper())

    fun register() {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    if (!libAvailable) {
                        result.error("unavailable", "Native llama.cpp library is not built.", null)
                        return@setMethodCallHandler
                    }
                    val path = call.argument<String>("path") ?: ""
                    val ctx = call.argument<Int>("contextSize") ?: 2048
                    val gpu = call.argument<Int>("gpuLayers") ?: -1
                    Thread {
                        val ok = nativeLoad(path, ctx, gpu)
                        loaded = ok
                        mainHandler.post {
                            if (ok) result.success(true)
                            else result.error("load_failed", "Nie udało się załadować modelu: $path", null)
                        }
                    }.start()
                }
                "generate" -> {
                    if (!loaded) {
                        result.error("not_loaded", "Model nie został załadowany.", null)
                        return@setMethodCallHandler
                    }
                    val prompt = call.argument<String>("prompt") ?: ""
                    Thread {
                        val text = nativeGenerate(prompt)
                        mainHandler.post { result.success(text) }
                    }.start()
                }
                "stop" -> {
                    nativeStop()
                    result.success(null)
                }
                "unload" -> {
                    nativeUnload()
                    loaded = false
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
