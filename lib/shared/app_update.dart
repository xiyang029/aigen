import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/api_client.dart';
import 'app_ui.dart';

class AppUpdateChecker {
  AppUpdateChecker({
    required this.api,
    required this.context,
    this.onDownloadingChanged,
  });

  static const _installerChannel = MethodChannel('com.xiyang.aigen/installer');
  static const _downloadNotificationId = 1001;

  // 服务端 API 客户端，用于查询版本和下载安装包。
  final ApiClient api;

  // 当前页面上下文，用于展示更新弹窗和提示。
  final BuildContext context;

  // 下载状态回调，用于同步页面按钮禁用状态。
  final ValueChanged<bool>? onDownloadingChanged;

  // 等待安装权限后需要继续打开的 APK 路径。
  String? _pendingInstallApkPath;

  // 标记是否正在等待用户授予安装未知来源应用权限。
  bool _waitingInstallPermission = false;

  // 防止重复触发下载安装流程。
  bool _downloading = false;

  // 记录上次通知栏进度，避免高频刷新系统通知。
  int _lastNotifiedProgress = -1;

  Future<void> check({
    bool silentWhenLatest = false,
    bool silentError = false,
  }) async {
    try {
      final results = await Future.wait([
        PackageInfo.fromPlatform(),
        api.fetchLatestRelease(),
      ]);
      if (!context.mounted) return;
      final packageInfo = results[0] as PackageInfo;
      final release = results[1] as AppReleaseInfo;
      if (!_isVersionNewer(release.version, packageInfo.version)) {
        if (!silentWhenLatest) {
          ShadToaster.of(context).show(ShadToast(title: Text('当前已是最新版本')));
        }
        return;
      }

      final shouldDownload = await _showUpdateDialog(
        currentVersion: packageInfo.version,
        release: release,
      );
      if (shouldDownload) await _downloadAndInstallRelease(release);
    } catch (error) {
      if (!context.mounted || silentError) return;
      ShadToaster.of(
        context,
      ).show(ShadToast(title: Text('检查更新失败：${error.toString()}')));
    }
  }

  Future<void> resumePendingInstallIfPossible() async {
    if (!_waitingInstallPermission || _pendingInstallApkPath == null) return;
    final allowed = await _canInstallPackages();
    if (!allowed) return;
    final apkPath = _pendingInstallApkPath;
    _waitingInstallPermission = false;
    _pendingInstallApkPath = null;
    if (apkPath != null) {
      await _openDownloadedApk(apkPath);
    }
  }

  Future<bool> _showUpdateDialog({
    required String currentVersion,
    required AppReleaseInfo release,
  }) async {
    if (!context.mounted) return false;
    final shouldDownload =
        await showShadDialog<bool>(
          context: context,
          builder: (context) => ShadDialog.alert(
            title: const Text('发现新版本'),
            description: Text(
              '当前版本 $currentVersion，最新版本 ${release.version}。\n',
            ),
            actions: [
              ShadButton.outline(
                child: const Text('稍后'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ShadButton(
                leading: const Icon(LucideIcons.download, size: 18),
                child: const Text('下载'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;
    return shouldDownload;
  }

  Future<void> _downloadAndInstallRelease(AppReleaseInfo release) async {
    if (_downloading) return;
    _lastNotifiedProgress = -1;
    _setDownloading(true);

    try {
      await _showDownloadNotification(
        title: '正在下载更新',
        content: '准备下载 ${release.version}',
        progress: 0,
      );
      final file = await api.downloadReleaseApk(
        release,
        onProgress: (receivedBytes, totalBytes) {
          if (totalBytes != null && totalBytes > 0) {
            final progress = (receivedBytes / totalBytes * 100)
                .clamp(0, 100)
                .round();
            if (progress != _lastNotifiedProgress) {
              _lastNotifiedProgress = progress;
              _showDownloadNotification(
                title: '正在下载更新',
                content: '$progress%',
                progress: progress,
              );
            }
          } else {
            final sizeText =
                '${(receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB';
            _showDownloadNotification(
              title: '正在下载更新',
              content: '已下载 $sizeText',
            );
          }
        },
      );
      await _showDownloadNotification(
        title: '下载完成',
        content: '正在打开安装包',
        progress: 100,
        completed: true,
      );
      await _openDownloadedApk(file.path);
    } catch (error) {
      await _showDownloadNotification(
        title: '下载失败',
        content: error.toString(),
        failed: true,
      );
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast(title: Text('下载更新失败：${error.toString()}')));
      }
    } finally {
      _setDownloading(false);
    }
  }

  Future<void> _showDownloadNotification({
    required String title,
    required String content,
    int? progress,
    bool completed = false,
    bool failed = false,
  }) async {
    try {
      await _installerChannel.invokeMethod<void>('showDownloadNotification', {
        'id': _downloadNotificationId,
        'title': title,
        'content': content,
        'progress': progress,
        'completed': completed,
        'failed': failed,
      });
    } catch (_) {
      // 系统通知不可用时不中断下载和安装流程。
    }
  }

  Future<bool> _canInstallPackages() async {
    try {
      final allowed = await _installerChannel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      return allowed ?? false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _openInstallPermissionSettings() async {
    await _installerChannel.invokeMethod<void>('openInstallPermissionSettings');
  }

  Future<void> _openDownloadedApk(String apkPath) async {
    final allowed = await _canInstallPackages();
    if (!allowed) {
      _pendingInstallApkPath = apkPath;
      _waitingInstallPermission = true;
      await _openInstallPermissionSettings();
      return;
    }

    await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
  }

  void _setDownloading(bool value) {
    _downloading = value;
    onDownloadingChanged?.call(value);
  }

  bool _isVersionNewer(String latest, String current) {
    final latestParts = _versionParts(latest);
    final currentParts = _versionParts(current);
    final length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;
    for (var index = 0; index < length; index++) {
      final latestPart = index < latestParts.length ? latestParts[index] : 0;
      final currentPart = index < currentParts.length ? currentParts[index] : 0;
      if (latestPart != currentPart) return latestPart > currentPart;
    }
    return false;
  }

  List<int> _versionParts(String version) {
    return version
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
