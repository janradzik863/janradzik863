package app.czarnewilki

import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Aktywność główna aplikacji Czarne Wilki.
 *
 * Kanały mostu do warstwy Flutter:
 *  - „cw/accessibility” — usługa dostępności (drzewo ekranu, akcje),
 *  - „cw/files”         — systemowe dialogi SAF do zapisu/odczytu
 *                         pliku kopii zapasowej (Storage Access Framework).
 */
class MainActivity : FlutterActivity() {

    private var pendingFilesResult: MethodChannel.Result? = null
    private var pendingJson: String? = null

    // ------------------------------------------------- dialogi SAF (kopia)

    private val createDocument =
        registerForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri: Uri? ->
            val result = pendingFilesResult
            val content = pendingJson
            pendingFilesResult = null
            pendingJson = null
            if (uri == null) {
                result?.error("CANCELLED", "Anulowano zapis", null)
                return@registerForActivityResult
            }
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { out ->
                    out.write((content ?: "").toByteArray(Charsets.UTF_8))
                } ?: throw IllegalStateException("Nie udało się otworzyć pliku do zapisu")
                result?.success(uri.toString())
            } catch (e: Exception) {
                result?.error("WRITE_FAILED", e.message, null)
            }
        }

    private val openDocument =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
            val result = pendingFilesResult
            pendingFilesResult = null
            if (uri == null) {
                result?.error("CANCELLED", "Anulowano wybór pliku", null)
                return@registerForActivityResult
            }
            try {
                val text = contentResolver.openInputStream(uri)?.use { input ->
                    input.bufferedReader(Charsets.UTF_8).use { it.readText() }
                } ?: throw IllegalStateException("Nie udało się otworzyć pliku")
                result?.success(text)
            } catch (e: Exception) {
                result?.error("READ_FAILED", e.message, null)
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    // ------------------------------------------------------- kanały mostu

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1) Sterowanie ekranem (usługa dostępności).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cw/accessibility")
            .setMethodCallHandler { call, result ->
                val service = CwAccessibilityService.instance
                when (call.method) {
                    "isConnected" -> result.success(service != null)

                    "openSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }

                    "screenTree" -> {
                        if (service == null) {
                            result.error("NO_SERVICE", "Usługa dostępności wyłączona", null)
                        } else {
                            try {
                                result.success(service.serializeTree())
                            } catch (e: Exception) {
                                result.error("TREE_FAILED", e.message, null)
                            }
                        }
                    }

                    "tap" -> {
                        val x = (call.argument<Int>("x") ?: 0)
                        val y = (call.argument<Int>("y") ?: 0)
                        if (service == null) result.error("NO_SERVICE", null, null)
                        else result.success(service.tap(x.toFloat(), y.toFloat()))
                    }

                    "swipe" -> {
                        val x1 = (call.argument<Int>("x1") ?: 0).toFloat()
                        val y1 = (call.argument<Int>("y1") ?: 0).toFloat()
                        val x2 = (call.argument<Int>("x2") ?: 0).toFloat()
                        val y2 = (call.argument<Int>("y2") ?: 0).toFloat()
                        val dur = (call.argument<Int>("duration") ?: 300)
                        if (service == null) result.error("NO_SERVICE", null, null)
                        else result.success(service.swipe(x1, y1, x2, y2, dur.toLong()))
                    }

                    "setText" -> {
                        val nodeId = call.argument<String>("nodeId") ?: ""
                        val text = call.argument<String>("text") ?: ""
                        if (service == null) result.error("NO_SERVICE", null, null)
                        else result.success(service.setText(nodeId, text))
                    }

                    "globalAction" -> {
                        val action = call.argument<String>("action") ?: "back"
                        if (service == null) result.error("NO_SERVICE", null, null)
                        else result.success(service.globalAction(action))
                    }

                    else -> result.notImplemented()
                }
            }

        // 2) Pliki kopii zapasowej (SAF — dialogi systemowe).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cw/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveBackup" -> {
                        if (pendingFilesResult != null) {
                            result.error("BUSY", "Trwa poprzednia operacja plikowa", null)
                            return@setMethodCallHandler
                        }
                        pendingFilesResult = result
                        pendingJson = call.argument<String>("content") ?: ""
                        val name = call.argument<String>("fileName")
                            ?: "czarne_wilki_backup.json"
                        createDocument.launch(name)
                    }

                    "pickBackup" -> {
                        if (pendingFilesResult != null) {
                            result.error("BUSY", "Trwa poprzednia operacja plikowa", null)
                            return@setMethodCallHandler
                        }
                        pendingFilesResult = result
                        openDocument.launch(
                            arrayOf("application/json", "text/plain", "application/octet-stream")
                        )
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
