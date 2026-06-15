import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Android 系统 Toast 的统一调用入口。
class SystemToast {
  const SystemToast._();

  // Android 原生 Toast 的 Flutter 调用通道。
  static const MethodChannel _channel = MethodChannel(
    'com.xiyang.aigen/system_toast',
  );

  // 显示系统 Toast，空内容会被忽略以避免无效原生调用。
  static void show(String message) {
    final toastMessage = message.trim();
    if (toastMessage.isEmpty) return;
    unawaited(_showOnPlatform(toastMessage));
  }

  // 调用原生平台方法，并在非 Android 或通道异常时静默降级。
  static Future<void> _showOnPlatform(String message) async {
    try {
      await _channel.invokeMethod<void>('show', {'message': message});
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

// 在页面上下文仍有效时显示系统 Toast，避免调用处重复写 mounted 判断。
void showAppToast(BuildContext context, String message) {
  if (context.mounted) SystemToast.show(message);
}
