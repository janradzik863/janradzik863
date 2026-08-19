package app.czarnewilki

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject

/**
 * Natywna usługa dostępności: oczy i ręce agenta automatyzacji.
 *
 * Odczytuje hierarchię aktywnego okna (teksty, opisy, klasy, dokładne
 * prostokąty współrzędnych, flagi interaktywności) i wykonuje akcje
 * fizyczne: stuknięcia, gesty przewijania, wpisywanie tekstu
 * oraz akcje globalne (wstecz / ekran główny / powiadomienia).
 */
class CwAccessibilityService : AccessibilityService() {

    companion object {
        /** Aktywna instancja usługi (nie-null, gdy włączona w systemie). */
        var instance: CwAccessibilityService? = null
            private set

        private const val MAX_NODES = 400
        private const val MAX_DEPTH = 30
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Zdarzenia nie są buforowane — drzewo czytamy na żądanie.
    }

    override fun onInterrupt() {}

    // ---------------------------------------------------------- odczyt ekranu

    /**
     * Serializuje drzewo aktywnego okna do JSON-a:
     * {package, width, height, nodes:[{id,text,desc,cls,l,t,r,b,
     *  clickable,scrollable,editable}]}
     * Id węzła to ścieżka indeksów dzieci ("0/3/1") — używana do
     * ponownego odnalezienia węzła (np. przy wpisywaniu tekstu).
     */
    fun serializeTree(): String {
        val root = rootInActiveWindow
            ?: return JSONObject().put("nodes", JSONArray()).toString()

        val metrics = resources.displayMetrics
        val nodes = JSONArray()
        walk(root, "", 0, nodes)

        val json = JSONObject()
            .put("package", root.packageName?.toString() ?: "")
            .put("width", metrics.widthPixels)
            .put("height", metrics.heightPixels)
            .put("nodes", nodes)
        return json.toString()
    }

    private fun walk(
        node: AccessibilityNodeInfo,
        path: String,
        depth: Int,
        out: JSONArray,
    ) {
        if (depth > MAX_DEPTH || out.length() >= MAX_NODES) return

        val rect = Rect()
        node.getBoundsInScreen(rect)

        // Tylko węzły widoczne i mieszczące się na ekranie.
        val visible = node.isVisibleToUser && rect.width() > 0 && rect.height() > 0
        if (visible && rect.right > 0 && rect.bottom > 0) {
            val id = if (path.isEmpty()) "root" else path
            out.put(
                JSONObject()
                    .put("id", id)
                    .put("text", node.text?.toString() ?: "")
                    .put("desc", node.contentDescription?.toString() ?: "")
                    .put("cls", node.className?.toString() ?: "")
                    .put("l", rect.left).put("t", rect.top)
                    .put("r", rect.right).put("b", rect.bottom)
                    .put("clickable", node.isClickable)
                    .put("scrollable", node.isScrollable)
                    .put("editable", node.isEditable)
            )
        }

        for (i in 0 until node.childCount) {
            if (out.length() >= MAX_NODES) return
            val child = node.getChild(i) ?: continue
            val childPath = if (path.isEmpty()) "$i" else "$path/$i"
            walk(child, childPath, depth + 1, out)
        }
    }

    /** Odnajduje węzeł po ścieżce indeksów. */
    private fun findNode(id: String): AccessibilityNodeInfo? {
        if (id == "root") return rootInActiveWindow
        var node = rootInActiveWindow ?: return null
        for (part in id.split("/")) {
            val idx = part.toIntOrNull() ?: return null
            val child = node.getChild(idx) ?: return null
            node = child
        }
        return node
    }

    // --------------------------------------------------------------- akcje

    /** Fizyczne stuknięcie w punkt ekranu (dispatchGesture). */
    fun tap(x: Float, y: Float): Boolean {
        val path = Path().apply {
            moveTo(x, y)
            lineTo(x, y)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, 60)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        return dispatchGesture(gesture, null, null)
    }

    /** Gest przeciągnięcia (przewijanie). */
    fun swipe(x1: Float, y1: Float, x2: Float, y2: Float, durationMs: Long): Boolean {
        if (durationMs < 50) return false
        val path = Path().apply {
            moveTo(x1, y1)
            lineTo(x2, y2)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        return dispatchGesture(gesture, null, null)
    }

    /** Wpisanie tekstu do pola (ACTION_SET_TEXT na węźle). */
    fun setText(nodeId: String, text: String): Boolean {
        val node = findNode(nodeId) ?: return false
        val args = android.os.Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text
            )
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    /** Akcje globalne systemu. */
    fun globalAction(action: String): Boolean {
        return when (action) {
            "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
            "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
            "recents" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
            "notifications" -> performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
            else -> false
        }
    }

    /** Informacja o wersji środowiska (diagnostyka). */
    fun androidVersion(): Int = Build.VERSION.SDK_INT
}
