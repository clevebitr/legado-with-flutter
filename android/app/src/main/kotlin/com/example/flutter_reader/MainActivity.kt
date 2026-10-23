package com.example.flutter_reader

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The Android half of `core/platform/long_running_task.dart` (ADR-0043 §决策 3).
 *
 * A batch book-source check holds one `PARTIAL_WAKE_LOCK` while it runs, so the OS does not suspend
 * the process between requests. The batch check still has **no foreground service** of its own
 * (registered as open in `docs/dev/roadmap.md` §3.7); the only foreground service in the app is
 * `audio_service`'s media playback service (ADR-0054 §决策 4), declared in the manifest.
 *
 * Both calls are idempotent, and the lock is released in [onDestroy] as well, so a finished or
 * killed activity never leaves it held.
 *
 * The base class is `AudioServiceActivity` so the media notification can bring the app back to its
 * existing Flutter engine (ADR-0054 §决策 4); it is a drop-in replacement for `FlutterActivity`.
 */
class MainActivity : AudioServiceActivity() {
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
        // 音频播放的媒体通知（ADR-0054 §决策 4）：Android 13+ 需要运行时授权，
        // 否则前台服务的通知不会出现在通知栏。结果不等：被拒也不影响前台服务本身。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "request" -> {
                        requestNotificationPermission()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_REQUEST_CODE,
        )
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

        // 与 core/platform/audio_service_playback_notification.dart 的常量同名同值。
        private const val NOTIFICATION_CHANNEL = "flutter_reader/notification_permission"
        private const val NOTIFICATION_REQUEST_CODE = 1001
    }
}
