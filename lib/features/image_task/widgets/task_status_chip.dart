import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../shared/app_ui.dart';

class TaskStatusChip extends StatelessWidget {
  const TaskStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final meta = switch (status) {
      'queued' => (
        label: '排队中',
        bg: imageQueuedBadgeBackground,
        fg: imageQueuedBadgeForeground,
        icon: LucideIcons.clock,
      ),
      'running' => (
        label: '生成中',
        bg: imageRunningBadgeBackground,
        fg: imageRunningBadgeForeground,
        icon: LucideIcons.sparkles,
      ),
      'completed' => (
        label: '已完成',
        bg: const Color(0xFFEAF7EF),
        fg: const Color(0xFF157347),
        icon: LucideIcons.circleCheck,
      ),
      'failed' => (
        label: '失败',
        bg: const Color(0xFFFFECEA),
        fg: const Color(0xFFD92D20),
        icon: LucideIcons.circleAlert,
      ),
      _ => (
        label: status,
        bg: const Color(0xFFF2F4F7),
        fg: imageMutedText,
        icon: LucideIcons.info,
      ),
    };

    return ShadBadge(
      backgroundColor: meta.bg,
      foregroundColor: meta.fg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 14, color: meta.fg),
          const SizedBox(width: 4),
          Text(
            meta.label,
            style: TextStyle(
              color: meta.fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
