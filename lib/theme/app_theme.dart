import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const imageAccent = Color(0xFFFB7299);
const imageMutedText = Color(0xFF7E8492);
const imagePrimaryText = Color(0xFF2F3440);
const imageError = Color(0xFFE65C84);
const imagePagePadding = EdgeInsets.fromLTRB(16, AppGap.sm, 16, 30);

class AppGap {
  const AppGap._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
}

// 任务状态徽章配色，统一供任务列表和详情状态标识使用。
const imageRunningBadgeBackground = Color(0xFFF4F0FF);
const imageRunningBadgeForeground = Color(0xFF7C3AED);
const _appDialogTheme = ShadDialogTheme(
  useSafeArea: false,
  padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
  radius: BorderRadius.all(Radius.circular(16.0)),
  removeBorderRadiusWhenTiny: false,
);

ShadThemeData buildAppTheme() {
  return ShadThemeData(
    disableSecondaryBorder: true,
    colorScheme: const ShadZincColorScheme.light(
      primary: imageAccent,
      foreground: imagePrimaryText,
      mutedForeground: imageMutedText,
      ring: imageAccent,
      destructive: imageError,
    ),
    alertDialogTheme: _appDialogTheme,
    primaryDialogTheme: _appDialogTheme,
    sheetTheme: const ShadSheetTheme(
      useSafeArea: false,
      radius: BorderRadius.all(Radius.circular(16.0)),
    ),
    ghostButtonTheme: const ShadButtonTheme(
      hoverBackgroundColor: Colors.transparent,
      hoverForegroundColor: imageError,
    ),
  );
}
