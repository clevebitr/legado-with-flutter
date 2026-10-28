package com.example.flutter_reader

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
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
 * `audio_service`'s media playback service (ADR-0054 §决策 4), declared in the manifest. It does
 * show an ongoing **progress notification** (`SOURCE_CHECK_CHANNEL`, the Android half of
 * `core/platform/source_check_notification.dart`): that is a status surface visible while
 * backgrounded, not the thing keeping the process alive.
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
        // 批量校验的进度通知（与上游 `BookSourceCheckService` 的通知对齐）：校验仍在 Flutter
        // isolate 里跑，这条通知只是「后台也能看见进度」的状态面，不承担保活。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOURCE_CHECK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "progress" -> {
                        showSourceCheckNotification(call.arguments as? Map<*, *>, finished = false)
                        result.success(null)
                    }

                    "finished" -> {
                        showSourceCheckNotification(call.arguments as? Map<*, *>, finished = true)
                        result.success(null)
                    }

                    "cancel" -> {
                        getSystemService(NotificationManager::class.java)
                            .cancel(SOURCE_CHECK_NOTIFICATION_ID)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Shows (or updates) the batch check's notification.
     *
     * The channel is created with the **localized** name the Dart side passes, so the system
     * settings page follows the app language (C-UI-5 keeps user-visible strings in ARB).
     */
    private fun showSourceCheckNotification(arguments: Map<*, *>?, finished: Boolean) {
        val channelName = arguments?.get("channelName") as? String ?: return
        val title = arguments?.get("title") as? String ?: ""
        val text = arguments?.get("text") as? String ?: ""
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            // 结果不等：被拒时 notify 本身不会崩，只是不显示。
            requestNotificationPermission()
        }
        val channelId = sourceCheckChannel(channelName)
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setOnlyAlertOnce(true)
            .setAutoCancel(finished)
            .setOngoing(!finished)
        if (!finished) {
            val completed = (arguments?.get("completed") as? Number)?.toInt() ?: 0
            val total = (arguments?.get("total") as? Number)?.toInt() ?: 1
            val max = total.coerceAtLeast(1)
            builder.setProgress(max, completed.coerceIn(0, max), false)
        }
        getSystemService(NotificationManager::class.java)
            .notify(SOURCE_CHECK_NOTIFICATION_ID, builder.build())
    }

    private fun sourceCheckChannel(channelName: String): String {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(SOURCE_CHECK_CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    SOURCE_CHECK_CHANNEL_ID,
                    channelName,
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    setShowBadge(false)
                    setSound(null, null)
                },
            )
        }

        return SOURCE_CHECK_CHANNEL_ID
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

        // 与 core/platform/source_check_notification.dart 的常量同名同值。
        private const val SOURCE_CHECK_CHANNEL = "flutter_reader/source_check_notification"
        private const val SOURCE_CHECK_CHANNEL_ID = "book_source_check"
        private const val SOURCE_CHECK_NOTIFICATION_ID = 1002
    }
}
