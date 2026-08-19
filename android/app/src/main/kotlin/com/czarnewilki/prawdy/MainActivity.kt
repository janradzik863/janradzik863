package com.czarnewilki.prawdy

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val syncChannel = "czarne_wilki/sync"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            syncChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendEvent" -> {
                    // Most komunikacyjny (#1). W wersji produkcyjnej wysyła
                    // zdarzenia do desktopa przez szyfrowany kanał (WebRTC).
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Lokalny silnik LLM (llama.cpp) — wymaganie #4 / #19.
        NativeLlmEngine(flutterEngine.dartExecutor.binaryMessenger).register()

        // Samonaprawa / iniekcja kodu w locie — wymaganie #11.
        SelfHealService(this, flutterEngine.dartExecutor.binaryMessenger).register()

        // Ręczny mikrofon z ciągłym nasłuchem — wymaganie #2.
        MicrophoneService(this, flutterEngine.dartExecutor.binaryMessenger).register()

        // Usługa pierwszoplanowa dla nasłuchu Telegrama (praca w tle).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "czarne_wilki/telegram_fg"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, TelegramForegroundService::class.java)
                        .apply { action = TelegramForegroundService.ACTION_START }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    val intent = Intent(this, TelegramForegroundService::class.java)
                        .apply { action = TelegramForegroundService.ACTION_STOP }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Most do usługi sterowania ekranem (agent automatyzacji — #8).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "czarne_wilki/screen"
        ).setMethodCallHandler { call, result ->
            val svc = ScreenControlService.instance
            if (svc == null) {
                result.error("unavailable", "Usługa dostępności nie jest włączona.", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "hierarchy" -> result.success(svc.describeTextNodes())
                "clickable" -> result.success(svc.describeClickableNodes())
                "click" -> {
                    val x = (call.argument<Number>("x"))?.toFloat() ?: 0f
                    val y = (call.argument<Number>("y"))?.toFloat() ?: 0f
                    result.success(svc.clickAt(x, y))
                }
                "clickText" -> result.success(svc.clickByText(call.argument<String>("text") ?: ""))
                "type" -> result.success(svc.findEditableAndType(call.argument<String>("text") ?: ""))
                "scroll" -> result.success(svc.scroll(call.argument<String>("direction") ?: "down"))
                "global" -> result.success(svc.performGlobalAction(call.argument<String>("action") ?: "back"))
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
}
