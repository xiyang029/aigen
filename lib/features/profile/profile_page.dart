import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../shared/app_update.dart';
import '../api_config/api_config_page.dart';
import '../prompt_tools/prompt_tools_page.dart';
import '../../shared/app_ui.dart';
import '../../theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.api, required this.onLogout});

  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  AppUser? _user;
  AppUpdateChecker? _updateChecker;
  String _currentVersion = '';
  bool _loadingUser = true;
  bool _clearingImageCache = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _loadVersion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateChecker ??= AppUpdateChecker(api: widget.api, context: context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_updateChecker?.resumePendingInstallIfPossible());
    }
  }

  Future<void> _loadUser() async {
    if (mounted) setState(() => _loadingUser = true);
    try {
      final user = await widget.api.me();
      if (!mounted) return;
      setState(() => _user = user);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else {
        if (!mounted) return;
        showAppToast(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _currentVersion = info.version);
  }

  Future<void> _handleUnauthorized() async {
    await widget.api.logout();
    if (!mounted) return;
    widget.onLogout();
  }

  Future<void> _logout() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '退出登录',
      description: '确定要退出当前账号吗？',
      confirmText: '退出',
      confirmIcon: LucideIcons.logOut,
    );
    if (!confirmed) return;
    await widget.api.logout();
    if (!mounted) return;
    widget.onLogout();
  }

  Future<void> _openApiConfigs() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ApiConfigPage(api: widget.api)));
  }

  Future<void> _openPromptTools() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PromptToolsPage(api: widget.api)));
  }

  Future<void> _changePassword() async {
    final changed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ChangePasswordDialog(api: widget.api),
    );
    if (!mounted) return;
    if (changed == true) {
      showAppToast(context, '密码已修改');
    }
  }

  Future<void> _clearOldImageCache() async {
    if (_clearingImageCache) return;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除图片缓存',
      description: '确定要删除本地图片预览缓存吗？',
      confirmText: '删除',
      confirmIcon: LucideIcons.trash2,
    );
    if (!confirmed || !mounted) return;

    setState(() => _clearingImageCache = true);
    try {
      await DefaultCacheManager().emptyCache();
      await _clearLegacyDownloadedImageCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!mounted) return;
      showAppToast(context, '旧图片缓存已删除');
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, '删除缓存失败：${error.toString()}');
    } finally {
      if (mounted) setState(() => _clearingImageCache = false);
    }
  }

  Future<void> _clearLegacyDownloadedImageCache() async {
    final baseDir = await getApplicationCacheDirectory();
    final legacyDir = Directory(
      '${baseDir.path}${Platform.pathSeparator}images',
    );
    if (await legacyDir.exists()) {
      await legacyDir.delete(recursive: true);
    }
  }

  Future<void> _checkForUpdates() async {
    await _updateChecker?.check();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final user = _user;
    final displayName = (user?.displayName ?? '').trim();
    final accountName = displayName.isNotEmpty ? displayName : '咕咕Do 用户';
    final actions = <({String label, IconData icon, VoidCallback? onPressed})>[
      (label: '提示词工具', icon: LucideIcons.brain, onPressed: _openPromptTools),
      (label: 'API 配置管理', icon: LucideIcons.key, onPressed: _openApiConfigs),
      (label: '修改密码', icon: LucideIcons.keyRound, onPressed: _changePassword),
      (
        label: _currentVersion.isEmpty ? '当前版本' : '当前版本 $_currentVersion',
        icon: LucideIcons.info,
        onPressed: null,
      ),
      (label: '检查更新', icon: LucideIcons.refreshCw, onPressed: _checkForUpdates),
      (
        label: _clearingImageCache ? '清理中...' : '删除图片缓存',
        icon: LucideIcons.trash2,
        onPressed: _clearingImageCache ? null : _clearOldImageCache,
      ),
      (label: '退出登录', icon: LucideIcons.logOut, onPressed: _logout),
    ];

    return AppPageScaffold(
      onRefresh: _loadUser,
      children: [
        ShadCard(
          child: Row(
            children: [
              SizedBox.square(
                dimension: 52,
                child: Center(
                  child: Icon(
                    LucideIcons.user,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _loadingUser
                    ? const Text('正在加载账号信息...')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(accountName, style: theme.textTheme.h4),
                          const SizedBox(height: AppGap.xs),
                          Text(
                            user?.email ?? '未获取到账号信息',
                            style: theme.textTheme.muted,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppGap.sm),
        ShadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const Divider(height: 1, indent: 0),
                _ProfileActionRow(
                  label: actions[index].label,
                  icon: actions[index].icon,
                  onPressed: actions[index].onPressed,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final enabled = onPressed != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
              size: 20,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label, style: enabled ? null : theme.textTheme.muted),
            ),
            if (enabled)
              Icon(
                LucideIcons.chevronRight,
                color: theme.colorScheme.mutedForeground,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key, required this.api});

  final ApiClient api;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _oldPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  void _clearError() {
    if (_errorMessage == null) return;
    setState(() => _errorMessage = null);
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldPassword = _oldPasswordController.text;
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (oldPassword.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = '请填写完整密码信息');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = '两次输入的新密码不一致');
      return;
    }
    if (_submitting) return;
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await widget.api.changePassword(
        oldPassword: oldPassword,
        password: password,
      );
      if (mounted) navigator.pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadDialog.alert(
      title: const Text('修改密码'),
      actions: [
        ShadButton.outline(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ShadButton(
          onPressed: _submitting ? null : _submit,
          leading: _submitting
              ? const AppLoadingSpinner(size: 16, color: Colors.white)
              : const Icon(LucideIcons.check),
          child: const Text('保存'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppObscuredInput(
            controller: _oldPasswordController,
            placeholder: '当前密码',
            icon: LucideIcons.lock,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: 10),
          AppObscuredInput(
            controller: _passwordController,
            placeholder: '新密码',
            icon: LucideIcons.keyRound,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: 10),
          AppObscuredInput(
            controller: _confirmController,
            placeholder: '确认新密码',
            icon: LucideIcons.checkCheck,
            onChanged: (_) => _clearError(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.circleAlert,
                  size: 16,
                  color: theme.colorScheme.destructive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: theme.colorScheme.destructive,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
