import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'features/auth/auth_page.dart';
import 'features/gallery/image_gallery_page.dart';
import 'features/image_gen/image_gen_page.dart';
import 'features/image_task/image_task_list_page.dart';
import 'features/profile/profile_page.dart';
import 'models/image_task.dart';
import 'services/api_client.dart';
import 'shared/app_ui.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize();
  runApp(const AigenApp());
}

class AigenApp extends StatefulWidget {
  const AigenApp({super.key});

  @override
  State<AigenApp> createState() => _AigenAppState();
}

class _AigenAppState extends State<AigenApp> {
  final ApiClient _api = ApiClient();
  bool _loading = true;
  bool _authed = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _api.load();
    if (_api.hasToken) {
      try {
        await _api.me().timeout(const Duration(seconds: 3));
        _authed = true;
      } on ApiException catch (error) {
        if (error.statusCode == 401) {
          await _api.logout();
        } else {
          _authed = true;
        }
      } catch (_) {
        _authed = true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final home = _loading
        ? const _Splash()
        : _authed
        ? AppShellPage(
            api: _api,
            onLogout: () => setState(() => _authed = false),
          )
        : AuthPage(api: _api, onAuthed: () => setState(() => _authed = true));

    return ShadApp.custom(
      theme: buildAppTheme(),
      appBuilder: (context) {
        return MaterialApp(
          title: '咕咕Do',
          debugShowCheckedModeBanner: false,
          theme: Theme.of(context),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          home: home,
        );
      },
    );
  }
}

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.api, required this.onLogout});

  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final _homeKey = GlobalKey<ImageGenPageState>();
  int _currentIndex = 0;

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _homeKey.currentState?.clearFocus();
    setState(() => _currentIndex = index);
  }

  void _openHomeWithDraft(TaskReuseDraft draft) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _currentIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.applyReuseDraft(draft);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ImageGenPage(key: _homeKey, api: widget.api, onLogout: widget.onLogout),
      ImageTaskListPage(api: widget.api, onReuseDraft: _openHomeWithDraft),
      ImageGalleryPage(api: widget.api),
      ProfilePage(api: widget.api, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _AppTabBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}

class _AppTabBar extends StatelessWidget {
  const _AppTabBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (label: '首页', icon: LucideIcons.house),
      (label: '任务', icon: LucideIcons.listTodo),
      (label: '发现', icon: LucideIcons.compass),
      (label: '我的', icon: LucideIcons.user),
    ];

    return SafeArea(
      child: SizedBox(
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ShadTheme.of(context).colorScheme.background,
            border: Border(
              top: BorderSide(color: ShadTheme.of(context).colorScheme.border),
            ),
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: selected
                            ? ShadTheme.of(context).colorScheme.primary
                            : ShadTheme.of(context).colorScheme.mutedForeground,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? ShadTheme.of(context).colorScheme.primary
                              : ShadTheme.of(
                                  context,
                                ).colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: AppLoadingSpinner(size: 36, strokeWidth: 3)),
    );
  }
}
