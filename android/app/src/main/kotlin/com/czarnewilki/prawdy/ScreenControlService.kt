package com.czarnewilki.prawdy

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Natywna usługa dostępności (#8).
 *
 * Interpretuje drzewo widoków (AccessibilityNodeInfo), oblicza współrzędne
 * elementów interaktywnych i wykonuje wieloetapowe zadania (klikanie,
 * wprowadzanie tekstu, przewijanie) na dowolnej zainstalowanej aplikacji.
 *
 * Uwaga: w tej klasie celowo NIE ma autozatrzymywania żadnej sesji — nasłuch
 * trwa do jawnego wywołania stop* (wymaganie #2).
 */
class ScreenControlService : AccessibilityService() {

    companion object {
        private const val TAG = "ScreenControl"
        var instance: ScreenControlService? = null
            private set
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "Usługa sterowania ekranem połączona.")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Ciągły nasłuch drzewa widoków — bez autozatrzymywania (#2).
        if (event == null) return
        val root = rootInActiveWindow ?: return
        // Hierarchia ekranu jest dostępna dla pętli sprzężenia zwrotnego AI.
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    /** Zwraca listę klikalnych węzłów wraz z ich współrzędnymi. */
    fun describeClickableNodes(): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        val root = rootInActiveWindow ?: return result
        collectNodes(root, result)
        return result
    }

    private fun collectNodes(node: AccessibilityNodeInfo, out: MutableList<Map<String, Any>>) {
        if (node.isClickable || node.isLongClickable) {
            val rect = android.graphics.Rect()
            node.getBoundsInScreen(rect)
            out.add(
                mapOf(
                    "text" to (node.text?.toString() ?: ""),
                    "contentDescription" to (node.contentDescription?.toString() ?: ""),
                    "className" to (node.className?.toString() ?: ""),
                    "bounds" to listOf(rect.left, rect.top, rect.right, rect.bottom),
                    "centerX" to rect.exactCenterX(),
                    "centerY" to rect.exactCenterY()
                )
            )
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectNodes(child, out)
        }
    }

    /** Znajduje węzeł po tekście i wykonuje na nim kliknięcie. */
    fun clickByText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByText(text)
        if (nodes.isEmpty()) return false
        val node = nodes.first()
        val rect = android.graphics.Rect()
        node.getBoundsInScreen(rect)
        return clickAt(rect.exactCenterX(), rect.exactCenterY())
    }

    /** Symuluje fizyczne stuknięcie ekranu na podstawie współrzędnych (#8). */
    fun clickAt(x: Float, y: Float): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        val path = Path().apply { moveTo(x, y) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 80))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    /** Przewija bieżący ekran (ACTION_SCROLL_FORWARD / BACKWARD). */
    fun scroll(direction: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val action = if (direction == "up") {
            AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
        } else {
            AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
        }
        return root.performAction(action)
    }

    /** Akcja globalna: back / home / recents / notifications. */
    fun performGlobalAction(name: String): Boolean {
        val action = when (name) {
            "back" -> GLOBAL_ACTION_BACK
            "home" -> GLOBAL_ACTION_HOME
            "recents" -> GLOBAL_ACTION_RECENTS
            "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
            else -> return false
        }
        return performGlobalAction(action)
    }

    /** Znajduje pierwsze pole edytowalne i wpisuje w nie tekst. */
    fun findEditableAndType(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val node = findEditable(root) ?: return false
        val args = android.os.Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    private fun findEditable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findEditable(child)
            if (found != null) return found
        }
        return null
    }

    /** Pełna hierarchia węzłów z tekstem (dla AI — zrozumienie kontekstu). */
    fun describeTextNodes(): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        val root = rootInActiveWindow ?: return result
        collectTextNodes(root, result)
        return result
    }

    private fun collectTextNodes(node: AccessibilityNodeInfo, out: MutableList<Map<String, Any>>) {
        val text = node.text?.toString() ?: ""
        val desc = node.contentDescription?.toString() ?: ""
        if (text.isNotEmpty() || desc.isNotEmpty()) {
            val rect = android.graphics.Rect()
            node.getBoundsInScreen(rect)
            out.add(
                mapOf(
                    "text" to text,
                    "description" to desc,
                    "clickable" to node.isClickable,
                    "editable" to node.isEditable,
                    "scrollable" to node.isScrollable,
                    "className" to (node.className?.toString() ?: ""),
                    "centerX" to rect.exactCenterX(),
                    "centerY" to rect.exactCenterY()
                )
            )
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectTextNodes(child, out)
        }
    }

    /** Wprowadza tekst w polu o danym identyfikatorze widoku. */
    fun setTextByResourceId(viewId: String, text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
        if (nodes.isEmpty()) return false
        val node = nodes.first()
        if (!node.isEditable) return false
        val args = android.os.Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }
}
