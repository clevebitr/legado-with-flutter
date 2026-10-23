package com.example.flutter_reader

import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The Android half of `core/platform/long_running_task.dart` (ADR-0043 §决策 3).
 *
 * A batch book-source check holds one `PARTIAL_WAKE_LOCK` while it runs, so the OS does not suspend
 * the process between requests. There is deliberately **no foreground service** in this iteration:
 * that needs a notification channel, a runtime `POST_NOTIFICATIONS` permission and service
 * lifecycle work, and it is registered as open in `docs/dev/roadmap.md` §3.7 with its trigger.
 *
 * Both calls are idempotent, and the lock is released in [onDestroy] as well, so a finished or
 * killed activity never leaves it held.
 */
class MainActivity : FlutterActivity() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        acquireWakeLock()
                        result.success(null)
                    }

                    "release" -> {
                        releaseWakeLock()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) {
            return
        }
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$WAKE_LOCK_TAG:$packageName")
            .apply { acquire() }
    }

    private fun releaseWakeLock() {
        val lock = wakeLock ?: return
        if (lock.isHeld) {
            lock.release()
        }
        wakeLock = null
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "flutter_reader/long_running_task"
        private const val WAKE_LOCK_TAG = "flutter_reader:book-source-check"
    }
}
