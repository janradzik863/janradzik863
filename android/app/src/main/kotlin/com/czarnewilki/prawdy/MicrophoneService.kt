package com.czarnewilki.prawdy

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * Ręczne sterowanie mikrofonem (wymaganie #2).
 *
 * Ciągły nasłuch PCM16 z AudioRecord — BEZ autozatrzymywania. Nagrywanie trwa
 * aż do jawnego wywołania `stop` przez użytkownika. W wersji produkcyjnej
 * surowe próbki PCM są konsumowane przez silnik STT (speech-to-text) na
 * urządzeniu lub zapisywane do pliku.
 */
class MicrophoneService(
    private val context: Context,
    private val messenger: io.flutter.plugin.common.BinaryMessenger
) {

    companion object {
        private const val TAG = "Microphone"
        private const val CHANNEL = "czarne_wilki/mic"
        private const val SAMPLE_RATE = 16000
    }

    @Volatile
    private var recording = false
    private var thread: Thread? = null
    private var audioRecord: AudioRecord? = null

    fun register() {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> result.success(start())
                "stop" -> result.success(stop())
                "isRecording" -> result.success(recording)
                else -> result.notImplemented()
            }
        }
    }

    private fun start(): Boolean {
        if (recording) return true
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Brak uprawnienia RECORD_AUDIO.")
            return false
        }
        return try {
            val minBuf = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuf <= 0) return false
            val ar = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                minBuf * 2
            )
            ar.startRecording()
            audioRecord = ar
            recording = true
            thread = Thread {
                val buf = ByteArray(minBuf)
                while (recording) {
                    val n = audioRecord?.read(buf, 0, buf.size) ?: -1
                    if (n <= 0) break
                    // Surowe próbki PCM16. Bez żadnego autozatrzymywania (#2).
                }
            }.apply { start() }
            Log.i(TAG, "Nasłuch rozpoczęty (ciągły, do jawnego Stop).")
            true
        } catch (e: Exception) {
            Log.e(TAG, "start failed", e)
            false
        }
    }

    private fun stop(): Boolean {
        recording = false
        return try {
            thread?.join(500)
            thread = null
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            Log.i(TAG, "Nasłuch zatrzymany.")
            true
        } catch (e: Exception) {
            Log.e(TAG, "stop failed", e)
            false
        }
    }
}
