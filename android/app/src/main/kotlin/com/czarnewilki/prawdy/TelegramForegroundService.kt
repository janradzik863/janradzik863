package com.czarnewilki.prawdy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Usługa pierwszoplanowa dla nasłuchu Telegrama (zdalny dostęp agenta).
 *
 * Utrzymuje proces przy życiu, dzięki czemu ankieta `getUpdates` działa,
 * gdy aplikacja jest w tle. Bez tego Android może uśpić polling.
 */
class TelegramForegroundService : Service() {

    companion object {
        private const val TAG = "TelegramFgSvc"
        private const val CHANNEL_ID = "cwp_telegram"
        private const val NOTIF_ID = 1001
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
        }
        startInForeground()
        return START_STICKY
    }

    private fun startInForeground() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Telegram nasłuch",
                NotificationManager.IMPORTANCE_LOW
            )
            nm.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notif = builder
            .setContentTitle("Czarne Wilki Prawdy")
            .setContentText("Nasłuch poleceń Telegram aktywny.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()
        try {
            startForeground(NOTIF_ID, notif)
            Log.i(TAG, "Usługa pierwszoplanowa uruchomiona.")
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
        }
    }
}
