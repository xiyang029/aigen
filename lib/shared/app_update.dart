import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/api_client.dart';
import 'app_ui.dart';

class AppUpdateChecker {
  AppUpdateChecker({required this.api, required this.context});

  static const _installerChannel = MethodChannel('com.xiyang.aigen/installer');

  /// 后端与 GitHub Release API 访问客户端。
  final ApiClient api;

  /// 用于弹窗、Toast 和安装权限恢复的页面上下文。
  final BuildContext context;

  /// 等待用户授权未知来源安装后继续安装的 APK 路径。
  String? _pendingInstallApkPath;

  /// 标记是否正在等待未知来源安装权限。
  bool _waitingInstallPermission = false;

  /// 防止重复创建后台更新下载任务。
  bool _downloading = false;

  /// 检查最新版本，并按当前设备 ABI 直接后台下载更新包。
  Future<void> check({
    bool silentWhenLatest = false,
    bool silentError = false,
  }) async {
    try {
      final results = await Future.wait([
        PackageInfo.fromPlatform(),
        _currentReleaseAbi(),
      ]);
      if (!context.mounted) return;
      final packageInfo = results[0] as PackageInfo;
      final releaseAbi = results[1] as String;
      final release = await api.fetchLatestRelease(abi: releaseAbi);
      if (!context.mounted) return;
      if (!_isVersionNewer(release.version, packageInfo.version)) {
        if (!silentWhenLatest) {
          showAppToast(context, '当前已是最新版本');
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
      showAppToast(context, '检查更新失败：${error.toString()}');
    }
  }

  /// 用户从系统设置返回后，如果权限已允许则继续安装。
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

  /// 显示发现新版本确认弹窗，避免误触后直接下载更新。
  Future<bool> _showUpdateDialog({
    required String currentVersion,
    required AppReleaseInfo release,
  }) async {
    if (!context.mounted) return false;
    return await showShadDialog<bool>(
          context: context,
          builder: (context) => ShadDialog.alert(
            title: const Align(
              alignment: Alignment.centerLeft,
              child: Text('发现新版本'),
            ),
            description: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前版本 $currentVersion\n'
                '最新版本 ${release.version}\n',
                textAlign: TextAlign.left,
              ),
            ),
            actions: [
              ShadButton.outline(
                child: const Text('稍后'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ShadButton(
                leading: const Icon(LucideIcons.download, size: 18),
                child: const Text('后台下载'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 创建后台下载任务，等待校验完成后拉起安装器。
  Future<void> _downloadAndInstallRelease(AppReleaseInfo release) async {
    if (_downloading || !context.mounted) return;
    _downloading = true;

    try {
      final notificationAllowed =
          (await _installerChannel.invokeMethod<bool>(
            'requestPostNotifications',
          )) ??
          false;
      if (!notificationAllowed) {
        if (!context.mounted) return;
        showAppToast(context, '请允许通知权限后再下载更新');
        return;
      }
      if (context.mounted) {
        showAppToast(context, '已开始后台下载，请查看系统通知进度');
      }
      final file = await api.downloadReleaseApkWithDownloader(release);
      await _openDownloadedApk(file.path);
    } catch (error) {
      if (context.mounted) {
        showAppToast(context, '下载更新失败：${error.toString()}');
      }
    } finally {
      _downloading = false;
    }
  }

  /// 查询是否允许本应用请求安装 APK。
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

  /// 打开允许安装未知来源应用的系统设置页。
  Future<void> _openInstallPermissionSettings() async {
    await _installerChannel.invokeMethod<void>('openInstallPermissionSettings');
  }

  /// 权限满足时打开下载好的 APK，否则先引导用户授权。
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

  /// 判断 GitHub Release 版本是否高于当前安装版本。
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

  /// 将版本字符串拆成用于比较的数字片段。
  List<int> _versionParts(String version) {
    return version
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }

  /// 从 Android 设备信息中选择当前设备支持的 Release ABI。
  Future<String> _currentReleaseAbi() async {
    if (!Platform.isAndroid) throw ApiException('当前平台不支持 APK 自动更新');
    final info = await DeviceInfoPlugin().androidInfo;
    for (final abi in info.supportedAbis) {
      if (ApiClient.supportedReleaseAbis.contains(abi)) return abi;
    }
    throw ApiException('当前设备 ABI 不支持自动更新：${info.supportedAbis.join(', ')}');
  }
}
