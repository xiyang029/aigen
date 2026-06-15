package com.xiyang.aigen

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 保存等待 Android 通知权限弹窗结果的 MethodChannel 回调。
    private var notificationPermissionResult: MethodChannel.Result? = null

    // 注册安装权限、通知权限和系统 Toast 相关的 Flutter 原生通道。
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

                "requestPostNotifications" -> requestPostNotifications(result)

                else -> result.notImplemented()
            }
        }

        // 注册 Android 系统 Toast 通道，供 Flutter 页面显示原生短提示。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.xiyang.aigen/system_toast",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    // Flutter 传入的提示文本，去空后用于系统 Toast 展示。
                    val message = call.argument<String>("message").orEmpty().trim()
                    if (message.isNotEmpty()) {
                        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // 接收 Android 权限弹窗结果并回传给 Flutter。
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return
        val allowed = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        notificationPermissionResult?.success(allowed)
        notificationPermissionResult = null
    }

    // 请求通知权限，用于显示后台下载进度通知。
    private fun requestPostNotifications(result: MethodChannel.Result) {
        val permission = Manifest.permission.POST_NOTIFICATIONS
        val currentState = ContextCompat.checkSelfPermission(this, permission)
        if (currentState == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        notificationPermissionResult?.success(false)
        notificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(permission),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }

    companion object {
        // 通知权限请求码，用于区分系统权限回调来源。
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
    }
}
