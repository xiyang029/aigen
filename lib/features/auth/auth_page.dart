import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../shared/app_ui.dart';

enum AuthMode { login, register, forgot }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.api, required this.onAuthed});

  final ApiClient api;
  final VoidCallback onAuthed;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _codeController = TextEditingController();
  AuthMode _mode = AuthMode.login;
  bool _loading = false;
  bool _resetStep = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_mode == AuthMode.login) {
        await widget.api.login(email: email, password: password);
        await widget.api.saveLogin(email: email, password: password);
        widget.onAuthed();
      } else if (_mode == AuthMode.register) {
        await widget.api.register(
          email: email,
          password: password,
          displayName: _displayNameController.text.trim(),
        );
        await widget.api.saveLogin(email: email, password: password);
        widget.onAuthed();
      } else if (_resetStep) {
        await widget.api.resetPassword(
          email: email,
          code: _codeController.text.trim(),
          password: password,
        );
        await widget.api.saveLogin(email: email, password: password);
        widget.onAuthed();
      } else {
        final message = await widget.api.forgotPassword(email);
        if (!mounted) return;
        setState(() => _resetStep = true);
        showAppToast(context, message);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSavedLogin() async {
    final saved = await widget.api.readSavedLogin();
    if (!mounted || saved == null) return;
    setState(() {
      _emailController.text = saved.email;
      _passwordController.text = saved.password;
    });
  }

  String get _title => switch (_mode) {
    AuthMode.login => '登录',
    AuthMode.register => '注册',
    AuthMode.forgot => _resetStep ? '重置密码' : '找回密码',
  };

  String get _subtitle => switch (_mode) {
    AuthMode.login => '欢迎回来，继续把想法变成图片。',
    AuthMode.register => '创建账号，保存你的生成任务与结果。',
    AuthMode.forgot => _resetStep ? '输入验证码并设置一个新密码。' : '我们会发送验证码到你的邮箱。',
  };

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.h1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 24),
                  ShadTabs<AuthMode>(
                    value: _mode,
                    onChanged: (value) => setState(() {
                      _mode = value;
                      _resetStep = false;
                    }),
                    tabBarConstraints: const BoxConstraints(
                      maxWidth: double.infinity,
                    ),
                    tabs: const [
                      ShadTab(
                        value: AuthMode.login,
                        content: SizedBox.shrink(),
                        child: AppTabLabel(
                          icon: LucideIcons.logIn,
                          label: '登录',
                          iconSize: 17,
                          gap: 5,
                        ),
                      ),
                      ShadTab(
                        value: AuthMode.register,
                        content: SizedBox.shrink(),
                        child: AppTabLabel(
                          icon: LucideIcons.userPlus,
                          label: '注册',
                          iconSize: 17,
                          gap: 5,
                        ),
                      ),
                      ShadTab(
                        value: AuthMode.forgot,
                        content: SizedBox.shrink(),
                        child: AppTabLabel(
                          icon: LucideIcons.rotateCcwKey,
                          label: '忘记',
                          iconSize: 17,
                          gap: 5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ShadInput(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    placeholder: const Text('邮箱'),
                    leading: const Icon(LucideIcons.mail, size: 18),
                  ),
                  if (_mode == AuthMode.register) ...[
                    const SizedBox(height: 12),
                    ShadInput(
                      controller: _displayNameController,
                      placeholder: const Text('昵称'),
                      leading: const Icon(LucideIcons.badge, size: 18),
                    ),
                  ],
                  if (_mode != AuthMode.forgot || _resetStep) ...[
                    const SizedBox(height: 12),
                    AppObscuredInput(
                      controller: _passwordController,
                      autofillHints: const [AutofillHints.password],
                      placeholder: _mode == AuthMode.login ? '密码' : '新密码',
                    ),
                  ],
                  if (_mode == AuthMode.forgot && _resetStep) ...[
                    const SizedBox(height: 12),
                    ShadInput(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      placeholder: const Text('6 位验证码'),
                      leading: const Icon(LucideIcons.pin, size: 18),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ShadButton(
                    onPressed: _loading ? null : _submit,
                    leading: _loading
                        ? const AppLoadingSpinner(color: Colors.white)
                        : const Icon(LucideIcons.arrowRight),
                    child: Text(_loading ? '处理中...' : _title),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
