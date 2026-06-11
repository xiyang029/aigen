import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const imageAccent = Color(0xFFFB7299);
const imageSoftBorder = Color(0xFFE7E9EE);
const imageMutedText = Color(0xFF7E8492);
const imagePrimaryText = Color(0xFF2F3440);
const imageSubtleFill = Color(0xFFF5F6F8);
const imageScaffoldBackground = Color(0xFFF7F8FA);
const imageError = Color(0xFFE65C84);
const imagePagePadding = EdgeInsets.fromLTRB(16, 8, 16, 30);

// 任务状态徽章配色，统一供任务列表和详情状态标识使用。
const imageQueuedBadgeBackground = Color(0xFFEEF6FF);
const imageQueuedBadgeForeground = Color(0xFF2563EB);
const imageRunningBadgeBackground = Color(0xFFF4F0FF);
const imageRunningBadgeForeground = Color(0xFF7C3AED);

ShadThemeData buildAppTheme() {
  return ShadThemeData(
    disableSecondaryBorder: true,
    colorScheme: const ShadZincColorScheme.light(
      primary: imageAccent,
      foreground: imagePrimaryText,
      mutedForeground: imageMutedText,
      background: imageScaffoldBackground,
      border: imageSoftBorder,
      input: imageSoftBorder,
      ring: imageAccent,
      destructive: imageError,
    ),
    alertDialogTheme: const ShadDialogTheme(
      useSafeArea: false,
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
      radius: BorderRadius.all(Radius.circular(16.0)),
      removeBorderRadiusWhenTiny: false,
    ),
    primaryDialogTheme: const ShadDialogTheme(
      useSafeArea: false,
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
      radius: BorderRadius.all(Radius.circular(16.0)),
      removeBorderRadiusWhenTiny: false,
    ),
    sheetTheme: const ShadSheetTheme(
      useSafeArea: false,
      radius: BorderRadius.all(Radius.circular(16.0)),
    ),
    primaryToastTheme: const ShadToastTheme(
      showCloseIconOnlyWhenHovered: false,
    ),
  );
}
