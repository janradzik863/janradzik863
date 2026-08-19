package com.czarnewilki.prawdy

import android.content.Context
import android.util.Log
import dalvik.system.DexClassLoader
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.lang.reflect.Method

/**
 * Samonaprawa i iniekcja kodu w locie (wymaganie #11).
 *
 * Android: dynamiczne ładowanie klas z pliku .dex przez DexClassLoader —
 * nowa logika działa natychmiast, bez reinstalacji aplikacji.
 * Desktop (odpowiednik): modyfikacja plików źródłowych — obsługiwana po
 * stronie Dart (patrz `SelfHealService.applySourcePatch`).
 */
class SelfHealService(private val context: Context, private val messenger: io.flutter.plugin.common.BinaryMessenger) {

    companion object {
        private const val TAG = "SelfHeal"
        private const val CHANNEL = "czarne_wilki/selfheal"
    }

    private var classLoader: DexClassLoader? = null

    fun register() {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    val ok = initLoader()
                    result.success(ok)
                }
                "loadDex" -> {
                    val path = call.argument<String>("path") ?: ""
                    val ok = loadDex(path)
                    result.success(ok)
                }
                "invokeClass" -> {
                    val className = call.argument<String>("className") ?: ""
                    val methodName = call.argument<String>("methodName") ?: ""
                    @Suppress("UNCHECKED_CAST")
                    val args = call.argument<List<Any>>("args") ?: emptyList()
                    val out = invokeClass(className, methodName, args)
                    result.success(out)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Przygotowuje katalogi poprawek i optymalizacji (bez ładowania pliku). */
    private fun initLoader(): Boolean {
        return try {
            val dexDir = File(context.filesDir, "patches").apply { mkdirs() }
            val optDir = File(context.cacheDir, "dexopt").apply { mkdirs() }
            Log.i(TAG, "Katalog poprawek gotowy: ${dexDir.absolutePath}; opt: ${optDir.absolutePath}")
            true
        } catch (e: Exception) {
            Log.e(TAG, "initLoader failed", e)
            false
        }
    }

    /** Ładuje klasy z pliku .dex do bieżącego procesu. */
    private fun loadDex(dexPath: String): Boolean {
        return try {
            val file = File(dexPath)
            if (!file.exists()) {
                Log.w(TAG, "Plik .dex nie istnieje: $dexPath")
                return false
            }
            val optDir = File(context.cacheDir, "dexopt").apply { mkdirs() }
            val loader = DexClassLoader(
                dexPath,
                optDir.absolutePath,
                null,
                context.classLoader
            )
            classLoader = loader
            Log.i(TAG, "Załadowano .dex: $dexPath")
            true
        } catch (e: Exception) {
            Log.e(TAG, "loadDex failed", e)
            false
        }
    }

    /** Wywołuje statyczną metodę z dynamicznie załadowanej klasy. */
    private fun invokeClass(className: String, methodName: String, args: List<Any>): Any? {
        return try {
            val clazz = classLoader?.loadClass(className)
                ?: return "class not loaded: $className"
            val method: Method = clazz.getMethod(methodName)
            method.invoke(null)
        } catch (e: Exception) {
            Log.e(TAG, "invokeClass failed: $className.$methodName", e)
            "error: ${e.message}"
        }
    }
}
