package com.xiyang.aigen

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 应用更新下载通知通道 ID，用于归类系统通知栏进度。
    private val downloadChannelId = "app_update_download"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureDownloadNotificationChannel()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.xiyang.aigen/installer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    val allowed = packageManager.canRequestPackageInstalls()
                    result.success(allowed)
                }

                "openInstallPermissionSettings" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName"),
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("open_settings_failed", error.message, null)
                    }
                }

                "showDownloadNotification" -> {
                    try {
                        showDownloadNotification(
                            id = call.argument<Int>("id") ?: 1001,
                            title = call.argument<String>("title") ?: "应用更新",
                            content = call.argument<String>("content") ?: "",
                            progress = call.argument<Int>("progress"),
                            completed = call.argument<Boolean>("completed") ?: false,
                            failed = call.argument<Boolean>("failed") ?: false,
                        )
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("show_notification_failed", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // 创建更新下载通知通道，用于显示应用更新包下载进度。
    private fun ensureDownloadNotificationChannel() {
        val channel = NotificationChannel(
            downloadChannelId,
            "应用更新下载",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "显示应用更新包下载进度"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    // 展示或刷新更新包下载通知，支持确定进度、未知大小、完成和失败状态。
    private fun showDownloadNotification(
        id: Int,
        title: String,
        content: String,
        progress: Int?,
        completed: Boolean,
        failed: Boolean,
    ) {
        if (!canPostNotifications()) return
        val statusIcon = if (completed) {
            android.R.drawable.stat_sys_download_done
        } else {
            android.R.drawable.stat_sys_download
        }
        val notification = NotificationCompat.Builder(this, downloadChannelId)
            .setSmallIcon(statusIcon)
            .setContentTitle(title)
            .setContentText(content)
            .setOnlyAlertOnce(true)
            .setOngoing(!completed && !failed)
            .setAutoCancel(completed || failed)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .apply {
                if (progress != null) {
                    setProgress(100, progress.coerceIn(0, 100), false)
                } else if (!completed && !failed) {
                    setProgress(0, 0, true)
                }
            }
            .build()
        NotificationManagerCompat.from(this).notify(id, notification)
    }

    // 检查通知权限，未授权时主动发起权限申请。
    private fun canPostNotifications(): Boolean {
        val granted = ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                1002,
            )
        }
        return granted
    }
}
