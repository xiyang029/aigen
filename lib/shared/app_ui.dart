import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../theme/app_theme.dart';

export 'package:shadcn_ui/shadcn_ui.dart'
    show
        LucideIcons,
        ShadBadge,
        ShadButton,
        ShadCard,
        ShadDialog,
        ShadIconButton,
        ShadInput,
        ShadOption,
        ShadSelect,
        ShadSlider,
        ShadSliderController,
        ShadTab,
        ShadTheme,
        ShadToast,
        ShadToaster,
        ShadTextarea,
        ShadTabs,
        showShadDialog,
        ShadSheet,
        ShadSheetTheme,
        ShadSheetSide,
        showShadSheet;

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.children,
    required this.onRefresh,
    this.controller,
    this.onBackgroundTap,
    this.padding = imagePagePadding,
    this.floatingActionButton,
  });

  final List<Widget> children;
  final Future<void> Function() onRefresh;
  final ScrollController? controller;
  final VoidCallback? onBackgroundTap;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final refreshList = RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        controller: controller,
        padding: padding,
        children: children,
      ),
    );

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: onBackgroundTap == null
            ? refreshList
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onBackgroundTap,
                child: refreshList,
              ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center, style: theme.textTheme.muted),
        ],
      ),
    );
  }
}

class AppLoadingSpinner extends StatelessWidget {
  const AppLoadingSpinner({
    super.key,
    this.size = 16,
    this.strokeWidth = 2,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? ShadTheme.of(context).colorScheme.primary,
      ),
    );
  }
}

class AppTabLabel extends StatelessWidget {
  const AppTabLabel({
    super.key,
    required this.icon,
    required this.label,
    this.iconSize = 16,
    this.gap = 6,
  });

  // 标签左侧展示的功能图标。
  final IconData icon;

  // 标签右侧展示的功能名称。
  final String label;

  // 图标尺寸，用于适配不同密度的标签栏。
  final double iconSize;

  // 图标和文字之间的间距。
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize),
        SizedBox(width: gap),
        Text(label),
      ],
    );
  }
}

class AppObscuredInput extends StatefulWidget {
  const AppObscuredInput({
    super.key,
    required this.controller,
    required this.placeholder,
    this.icon = LucideIcons.lock,
    this.autofillHints,
    this.textInputAction,
    this.onChanged,
  });

  // 输入框绑定的文本控制器。
  final TextEditingController controller;

  // 输入框未填写时展示的提示文案。
  final String placeholder;

  // 输入框左侧展示的语义图标。
  final IconData icon;

  // 系统自动填充提示。
  final Iterable<String>? autofillHints;

  // 键盘动作类型。
  final TextInputAction? textInputAction;

  // 文本变化回调。
  final ValueChanged<String>? onChanged;

  @override
  State<AppObscuredInput> createState() => _AppObscuredInputState();
}

class _AppObscuredInputState extends State<AppObscuredInput> {
  // 控制敏感内容是否隐藏。
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return ShadInput(
      controller: widget.controller,
      placeholder: Text(widget.placeholder),
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      leading: Icon(widget.icon, size: 18),
      onChanged: widget.onChanged,
      trailing: SizedBox.square(
        dimension: 24,
        child: OverflowBox(
          maxWidth: 28,
          maxHeight: 28,
          child: ShadIconButton(
            iconSize: 20,
            backgroundColor: Colors.transparent,
            foregroundColor: imageAccent,
            padding: const EdgeInsets.all(2),
            icon: Icon(_obscure ? LucideIcons.eyeOff : LucideIcons.eye),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }
}

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String description,
  required String confirmText,
  required IconData confirmIcon,
}) async {
  // 统一确认弹窗的按钮样式和布尔返回值。
  final confirmed = await showShadDialog<bool>(
    context: context,
    builder: (context) => ShadDialog.alert(
      title: Text(title),
      description: Text(description),
      actions: [
        ShadButton.outline(
          child: const Text('取消'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        ShadButton(
          leading: Icon(confirmIcon, size: 18),
          child: Text(confirmText),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class PagingStatusFooter extends StatelessWidget {
  const PagingStatusFooter({
    super.key,
    required this.isLoadingMore,
    required this.hasMore,
    required this.hasItems,
  });

  final bool isLoadingMore;
  final bool hasMore;
  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    if (!isLoadingMore && (hasMore || !hasItems)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isLoadingMore ? 16 : 12),
      child: Center(
        child: isLoadingMore
            ? const AppLoadingSpinner(size: 24)
            : Text('已经到底了', style: ShadTheme.of(context).textTheme.muted),
      ),
    );
  }
}
