import 'dart:async';

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
    this.onDownloadLabelChanged,
  });

  static const _installerChannel = MethodChannel('com.xiyang.aigen/installer');

  final ApiClient api;
  final BuildContext context;
  final ValueChanged<bool>? onDownloadingChanged;
  final ValueChanged<String?>? onDownloadLabelChanged;

  String? _pendingInstallApkPath;
  bool _waitingInstallPermission = false;
  bool _downloading = false;
  ValueNotifier<_DownloadDialogState>? _downloadStateNotifier;

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
    return await showShadDialog<bool>(
          context: context,
          builder: (context) => ShadDialog.alert(
            title: const Text('发现新版本'),
            description: Text(
              '当前版本 $currentVersion，最新版本 ${release.version}。\n'
              '安装包大小 ${_formatBytes(release.expectedSize)}。',
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
  }

  Future<void> _downloadAndInstallRelease(AppReleaseInfo release) async {
    if (_downloading || !context.mounted) return;
    _setDownloading(true);

    final stateNotifier = ValueNotifier(
      const _DownloadDialogState(
        title: '正在下载更新',
        message: '准备下载安装包...',
        progress: 0,
      ),
    );
    _downloadStateNotifier = stateNotifier;
    final dialogFuture = _showDownloadDialog(stateNotifier);

    try {
      final file = await api.downloadReleaseApk(
        release,
        onProgress: (receivedBytes, totalBytes) {
          final progress = totalBytes != null && totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0, 1).toDouble()
              : null;
          final percent = progress == null ? null : (progress * 100).round();
          final totalLabel = totalBytes == null ? null : _formatBytes(totalBytes);
          stateNotifier.value = _DownloadDialogState(
            title: '正在下载更新',
            message: percent == null
                ? '已下载 ${_formatBytes(receivedBytes)}'
                : '已下载 ${_formatBytes(receivedBytes)} / $totalLabel',
            progress: progress,
          );
          _setDownloadLabel(percent == null ? '更新中...' : '更新中 $percent%');
        },
      );

      stateNotifier.value = const _DownloadDialogState(
        title: '下载完成',
        message: '校验完成，正在打开安装包...',
        progress: 1,
      );
      _setDownloadLabel('准备安装...');
      await _closeDownloadDialog();
      await _openDownloadedApk(file.path);
    } catch (error) {
      stateNotifier.value = _DownloadDialogState(
        title: '下载失败',
        message: error.toString(),
        progress: null,
        canClose: true,
      );
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast(title: Text('下载更新失败：${error.toString()}')));
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _closeDownloadDialog();
    } finally {
      await dialogFuture;
      if (identical(_downloadStateNotifier, stateNotifier)) {
        _downloadStateNotifier = null;
      }
      stateNotifier.dispose();
      _setDownloading(false);
    }
  }

  Future<void> _showDownloadDialog(
    ValueNotifier<_DownloadDialogState> stateNotifier,
  ) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: ValueListenableBuilder<_DownloadDialogState>(
            valueListenable: stateNotifier,
            builder: (context, state, _) {
              final percent = state.progress == null
                  ? null
                  : (state.progress! * 100).round().clamp(0, 100);
              return ShadDialog(
                title: Text(state.title),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.message),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: state.progress),
                    const SizedBox(height: 10),
                    Text(
                      percent == null ? '下载中...' : '$percent%',
                      style: ShadTheme.of(context).textTheme.muted,
                    ),
                    if (state.canClose) ...[
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ShadButton.outline(
                          child: const Text('关闭'),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _closeDownloadDialog() async {
    if (_downloadStateNotifier == null || !context.mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
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
    if (!value) {
      _setDownloadLabel(null);
    }
  }

  void _setDownloadLabel(String? label) {
    onDownloadLabelChanged?.call(label);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final fractionDigits = unitIndex == 0 ? 0 : 1;
    return '${size.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
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

class _DownloadDialogState {
  const _DownloadDialogState({
    required this.title,
    required this.message,
    required this.progress,
    this.canClose = false,
  });

  final String title;
  final String message;
  final double? progress;
  final bool canClose;
}
