import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/image_task.dart';
import '../../../services/api_client.dart';
import 'task_status_chip.dart';
import '../../../shared/app_ui.dart';
import '../../../shared/image_preview_widgets.dart';

String formatImageTaskTime(String value) {
  final parsed = parseImageTaskTime(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
}

String formatImageTaskClockTime(String value) {
  final parsed = parseImageTaskTime(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

DateTime? parseImageTaskTime(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  final hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(normalized);
  return DateTime.tryParse(hasTimezone ? normalized : '${normalized}Z');
}

String formatImageTaskElapsedTime(ImageTaskSummary task) {
  final createdAt = parseImageTaskTime(task.createdAt);
  if (createdAt == null) return '--';

  final finishedAt = task.finishedAt == null || task.finishedAt!.isEmpty
      ? null
      : parseImageTaskTime(task.finishedAt!);
  final endTime = finishedAt ?? DateTime.now().toUtc();
  final elapsed = endTime.difference(createdAt.toUtc());
  final safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
  final text = formatImageTaskDuration(safeElapsed);
  return text;
}

String formatImageTaskDuration(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds < 1) return '<1秒';
  if (seconds < 60) return '$seconds秒';

  final minutes = duration.inMinutes;
  final remainingSeconds = seconds % 60;
  if (minutes < 60) {
    return '$minutes分${remainingSeconds.toString().padLeft(2, '0')}秒';
  }

  final hours = duration.inHours;
  final remainingMinutes = minutes % 60;
  return '$hours时${remainingMinutes.toString().padLeft(2, '0')}分'
      '${remainingSeconds.toString().padLeft(2, '0')}秒';
}

class ImageTaskTile extends StatelessWidget {
  const ImageTaskTile({
    super.key,
    required this.task,
    required this.formatTime,
    required this.formatElapsedTime,
    required this.onTap,
    this.showElapsedLoading = false,
  });

  final ImageTaskSummary task;
  final String Function(String) formatTime;
  final String Function(ImageTaskSummary) formatElapsedTime;
  final VoidCallback onTap;
  final bool showElapsedLoading;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.prompt.isEmpty ? task.id : task.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.p,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TaskStatusChip(status: task.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _IconText(
                    icon: task.mode == ImageMode.generate
                        ? LucideIcons.textCursorInput
                        : LucideIcons.image,
                    text: task.mode.label,
                  ),
                  const SizedBox(width: 10),
                  _IconText(
                    icon: LucideIcons.timer,
                    textWidget: _LiveElapsedText(
                      task: task,
                      formatter: formatElapsedTime,
                      style: theme.textTheme.muted,
                      isLoading: showElapsedLoading,
                    ),
                  ),
                  Spacer(),
                  _IconText(
                    icon: LucideIcons.clock,
                    text: formatImageTaskClockTime(task.createdAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageTaskCardList extends StatelessWidget {
  const ImageTaskCardList({
    super.key,
    required this.tasks,
    required this.onTaskTap,
    this.itemSpacing = 8,
    this.showElapsedLoading = false,
  });

  final List<ImageTaskSummary> tasks;
  final ValueChanged<ImageTaskSummary> onTaskTap;
  final double itemSpacing;
  final bool showElapsedLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final task in tasks)
          Padding(
            padding: EdgeInsets.only(bottom: itemSpacing),
            child: ImageTaskTile(
              task: task,
              formatTime: formatImageTaskTime,
              formatElapsedTime: formatImageTaskElapsedTime,
              onTap: () => onTaskTap(task),
              showElapsedLoading: showElapsedLoading,
            ),
          ),
      ],
    );
  }
}

class ImageTaskGroupedCardList extends StatelessWidget {
  const ImageTaskGroupedCardList({
    super.key,
    required this.groupedTasks,
    required this.onTaskTap,
    this.showElapsedLoading = false,
  });

  final Map<String, List<ImageTaskSummary>> groupedTasks;
  final ValueChanged<ImageTaskSummary> onTaskTap;
  final bool showElapsedLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in groupedTasks.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ShadBadge(child: Text('${entry.value.length} 条')),
              ],
            ),
          ),
          ImageTaskCardList(
            tasks: entry.value,
            onTaskTap: onTaskTap,
            showElapsedLoading: showElapsedLoading,
          ),
        ],
      ],
    );
  }
}

class ImageTaskDetailPanel extends StatelessWidget {
  const ImageTaskDetailPanel({
    super.key,
    required this.task,
    required this.api,
    required this.formatTime,
    required this.formatElapsedTime,
    required this.onRetry,
    required this.onDelete,
    required this.onDownload,
    required this.onReuseAsNew,
    required this.onReuseAsEdit,
    required this.isRetrying,
    required this.isReusing,
    this.showElapsedLoading = false,
  });

  final ImageTaskDetail? task;
  final ApiClient api;
  final String Function(String) formatTime;
  final String Function(ImageTaskSummary) formatElapsedTime;
  final VoidCallback onRetry;
  final VoidCallback onDelete;
  final Future<void> Function(String url) onDownload;
  final Future<void> Function() onReuseAsNew;
  final Future<void> Function() onReuseAsEdit;
  final bool isRetrying;
  final bool isReusing;
  final bool showElapsedLoading;

  @override
  Widget build(BuildContext context) {
    final current = task;
    if (current == null) return const SizedBox.shrink();

    final sourceImages = current.sourceImages;
    final images = current.result?.images ?? const <TaskResultImage>[];
    final sourcePreviewImages = sourceImages
        .map(
          (item) => PreviewImageItem(
            url: api.resolveUrl(item.url).toString(),
            cacheKey: api.cacheKeyForUrl(item.url),
            heroTag: 'source-${item.url}',
          ),
        )
        .toList();
    final previewImages = images
        .map(
          (item) => PreviewImageItem(
            url: api.resolveUrl(item.url).toString(),
            cacheKey: api.cacheKeyForUrl(item.url),
            heroTag: item.url,
          ),
        )
        .toList();
    final requestedSize = current.params?.requestedSize.trim();
    final hasRequestedSize = requestedSize != null && requestedSize.isNotEmpty;
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('任务详情', style: ShadTheme.of(context).textTheme.h4),
              ),
              if (current.isFailed)
                ShadIconButton.ghost(
                  onPressed: isRetrying ? null : onRetry,
                  icon: isRetrying
                      ? const AppLoadingSpinner(color: Colors.white)
                      : const Icon(LucideIcons.rotateCcw),
                  iconSize: 18,
                ),
              ShadIconButton.ghost(
                width: 32,
                height: 32,
                iconSize: 18,
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TaskStatusChip(status: current.status),
              _IconText(
                icon: LucideIcons.shapes,
                text: current.mode.label,
                pill: true,
              ),
              if (hasRequestedSize)
                _IconText(
                  icon: LucideIcons.ratio,
                  text: requestedSize,
                  pill: true,
                ),
              _IconText(
                icon: LucideIcons.clock,
                text: formatTime(current.createdAt),
                pill: true,
              ),
              _IconText(
                icon: LucideIcons.timer,
                textWidget: _LiveElapsedText(
                  task: current,
                  formatter: formatElapsedTime,
                  style: ShadTheme.of(context).textTheme.small,
                  isLoading: showElapsedLoading,
                ),
                pill: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!current.isActive) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ShadButton.outline(
                  onPressed: isReusing ? null : onReuseAsNew,
                  leading: isReusing
                      ? const AppLoadingSpinner(size: 16)
                      : const Icon(LucideIcons.clipboardPaste),
                  child: const Text('复用参数'),
                ),
                if (images.isNotEmpty)
                  ShadButton.outline(
                    onPressed: isReusing ? null : onReuseAsEdit,
                    leading: const Icon(LucideIcons.pencil),
                    child: const Text('编辑结果'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _PromptCard(title: '正向提示词', prompt: current.prompt),
          if (current.negativePrompt.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _PromptCard(title: '负面提示词', prompt: current.negativePrompt),
          ],
          if (current.isFailed && (current.errorMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: ShadTheme.of(context).radius,
                border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
              ),
              child: Text(current.errorMessage!),
            ),
          ],
          const SizedBox(height: 12),
          if (sourceImages.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('输入图片', style: ShadTheme.of(context).textTheme.h4),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 640 ? 3 : 2;
                return GridView.builder(
                  itemCount: sourceImages.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final image = sourceImages[index];
                    return ImagePreviewCard(
                      imageUrl: api.resolveUrl(image.url).toString(),
                      heroTag: 'source-${image.url}',
                      headers: api.authHeaders,
                      cacheKey: api.cacheKeyForUrl(image.url),
                      previewImages: sourcePreviewImages,
                      initialIndex: index,
                      onDownloadAt: (imageIndex) =>
                          onDownload(sourceImages[imageIndex].url),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Text('输出图片', style: ShadTheme.of(context).textTheme.h4),
          ),
          const SizedBox(height: 12),
          if (images.isEmpty)
            EmptyState(
              icon: current.isFailed
                  ? LucideIcons.circleAlert
                  : LucideIcons.hourglass,
              text: current.isFailed ? '任务失败，没有生成结果。' : '图片还在处理中，会自动刷新。',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 640 ? 3 : 2;
                return GridView.builder(
                  itemCount: images.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final image = images[index];
                    return ImagePreviewCard(
                      imageUrl: api.resolveUrl(image.url).toString(),
                      heroTag: image.url,
                      headers: api.authHeaders,
                      cacheKey: api.cacheKeyForUrl(image.url),
                      previewImages: previewImages,
                      initialIndex: index,
                      onDownloadAt: (imageIndex) =>
                          onDownload(images[imageIndex].url),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.title, required this.prompt});

  final String title;
  final String prompt;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!context.mounted) return;
    showAppToast(context, '$title已复制');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: ShadTheme.of(context).textTheme.muted),
            ),
            ShadIconButton.ghost(
              width: 32,
              height: 32,
              iconSize: 18,
              padding: EdgeInsets.zero,
              onPressed: () => _copy(context),
              icon: const Icon(LucideIcons.copy),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 110, maxHeight: 220),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ShadTheme.of(context).colorScheme.background,
              borderRadius: ShadTheme.of(context).radius,
              border: Border.all(
                color: ShadTheme.of(context).colorScheme.border,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              physics: const ClampingScrollPhysics(),
              child: SelectableText(
                prompt,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveElapsedText extends StatefulWidget {
  const _LiveElapsedText({
    required this.task,
    required this.formatter,
    this.style,
    this.isLoading = false,
  });

  final ImageTaskSummary task;
  final String Function(ImageTaskSummary) formatter;
  final TextStyle? style;
  final bool isLoading;

  @override
  State<_LiveElapsedText> createState() => _LiveElapsedTextState();
}

class _LiveElapsedTextState extends State<_LiveElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(_LiveElapsedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id ||
        oldWidget.task.status != widget.task.status ||
        oldWidget.isLoading != widget.isLoading) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    if (!widget.isLoading && widget.task.isActive) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      return;
    }
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Text(
        '同步中...',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: widget.style,
      );
    }
    return Text(
      widget.formatter(widget.task),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({
    required this.icon,
    this.text,
    this.textWidget,
    this.pill = false,
  }) : assert(text != null || textWidget != null);

  final IconData icon;
  final String? text;
  final Widget? textWidget;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final label =
        textWidget ??
        Text(
          text!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: pill ? null : theme.textTheme.muted,
        );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: pill ? null : theme.colorScheme.mutedForeground,
        ),
        SizedBox(width: pill ? 4 : 4),
        label,
      ],
    );
    return pill ? ShadBadge.secondary(child: content) : content;
  }
}
