import 'dart:io';
import 'package:flutter/material.dart';

import '../../../models/image_task.dart';
import '../../../shared/app_ui.dart';
import '../../../shared/image_preview_widgets.dart';
import '../../../theme/app_theme.dart';

class ImageRequestSheet extends StatelessWidget {
  const ImageRequestSheet({
    super.key,
    required this.mode,
    required this.promptController,
    required this.negativePromptController,
    required this.configId,
    required this.configs,
    required this.quality,
    required this.size,
    required this.outputFormat,
    required this.moderation,
    required this.background,
    required this.count,
    required this.images,
    required this.submitting,
    required this.onUnfocus,
    required this.onModeChanged,
    required this.onPickImages,
    required this.onPreviewImage,
    required this.onRemoveImage,
    required this.onConfigChanged,
    required this.onQualityChanged,
    required this.onSizeChanged,
    required this.onOutputFormatChanged,
    required this.onModerationChanged,
    required this.onBackgroundChanged,
    required this.onCountChanged,
    required this.onSubmit,
  });

  final ImageMode mode;
  final TextEditingController promptController;
  final TextEditingController negativePromptController;
  final String configId;
  final List<ImageApiConfig> configs;
  final String quality;
  final String size;
  final String outputFormat;
  final String moderation;
  final String background;
  final int count;
  final List<ReuseImageFile> images;
  final bool submitting;
  final VoidCallback onUnfocus;
  final ValueChanged<ImageMode> onModeChanged;
  final VoidCallback onPickImages;
  final ValueChanged<int> onPreviewImage;
  final ValueChanged<String> onRemoveImage;
  final ValueChanged<String> onConfigChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<String> onSizeChanged;
  final ValueChanged<String> onOutputFormatChanged;
  final ValueChanged<String> onModerationChanged;
  final ValueChanged<String> onBackgroundChanged;
  final ValueChanged<int> onCountChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadTabs<ImageMode>(
            value: mode,
            onChanged: onModeChanged,
            tabBarConstraints: const BoxConstraints(maxWidth: double.infinity),
            tabs: const [
              ShadTab(
                value: ImageMode.generate,
                content: SizedBox.shrink(),
                child: AppTabLabel(
                  icon: LucideIcons.textCursorInput,
                  label: '文生图',
                ),
              ),
              ShadTab(
                value: ImageMode.edit,
                content: SizedBox.shrink(),
                child: AppTabLabel(icon: LucideIcons.image, label: '图生图'),
              ),
            ],
          ),
          const SizedBox(height: AppGap.md),
          ShadTextarea(
            controller: promptController,
            onPressedOutside: (_) => onUnfocus(),
            minHeight: 112,
            maxHeight: 220,
            maxLength: 10000,
            placeholder: const Text('输入要生成的画面、风格、构图和细节'),
          ),
          const SizedBox(height: AppGap.sm),
          ShadTextarea(
            controller: negativePromptController,
            onPressedOutside: (_) => onUnfocus(),
            minHeight: 84,
            maxHeight: 160,
            maxLength: 10000,
            placeholder: const Text('反向提示词：描述不希望出现的内容，例如低清晰度、变形手指、多余文字'),
          ),
          if (mode == ImageMode.edit) ...[
            const SizedBox(height: AppGap.sm),
            _UploadPanel(
              images: images,
              onPickImages: onPickImages,
              onPreviewImage: onPreviewImage,
              onRemoveImage: onRemoveImage,
            ),
          ],
          const SizedBox(height: AppGap.md),
          _OptionGrid(
            configId: configId,
            configs: configs,
            quality: quality,
            size: size,
            outputFormat: outputFormat,
            moderation: moderation,
            background: background,
            count: count,
            onConfigChanged: onConfigChanged,
            onQualityChanged: onQualityChanged,
            onSizeChanged: onSizeChanged,
            onOutputFormatChanged: onOutputFormatChanged,
            onModerationChanged: onModerationChanged,
            onBackgroundChanged: onBackgroundChanged,
            onCountChanged: onCountChanged,
          ),
          const SizedBox(height: AppGap.sm),
          ShadButton(
            onPressed: submitting ? null : onSubmit,
            leading: submitting
                ? const AppLoadingSpinner(color: Colors.white)
                : const Icon(LucideIcons.sparkles),
            child: Text(
              submitting
                  ? '提交中...'
                  : (mode == ImageMode.generate ? '生成图片' : '提交编辑'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionGrid extends StatelessWidget {
  const _OptionGrid({
    required this.configId,
    required this.configs,
    required this.quality,
    required this.size,
    required this.outputFormat,
    required this.moderation,
    required this.background,
    required this.count,
    required this.onConfigChanged,
    required this.onQualityChanged,
    required this.onSizeChanged,
    required this.onOutputFormatChanged,
    required this.onModerationChanged,
    required this.onBackgroundChanged,
    required this.onCountChanged,
  });

  final String configId;
  final List<ImageApiConfig> configs;
  final String quality;
  final String size;
  final String outputFormat;
  final String moderation;
  final String background;
  final int count;
  final ValueChanged<String> onConfigChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<String> onSizeChanged;
  final ValueChanged<String> onOutputFormatChanged;
  final ValueChanged<String> onModerationChanged;
  final ValueChanged<String> onBackgroundChanged;
  final ValueChanged<int> onCountChanged;

  @override
  Widget build(BuildContext context) {
    final List<({String label, String value, List<ImageOption> options, ValueChanged<String> onChanged})> advancedFields = [
      (
        label: '质量',
        value: quality,
        options: qualityOptions,
        onChanged: onQualityChanged,
      ),
      (
        label: '尺寸',
        value: size,
        options: sizeOptions,
        onChanged: onSizeChanged,
      ),
      (
        label: '格式',
        value: outputFormat,
        options: outputFormatOptions,
        onChanged: onOutputFormatChanged,
      ),
      (
        label: '审核',
        value: moderation,
        options: moderationOptions,
        onChanged: onModerationChanged,
      ),
      (
        label: '背景',
        value: background,
        options: backgroundOptions,
        onChanged: onBackgroundChanged,
      ),
      (
        label: '生成数量',
        value: '$count',
        options: List.generate(
          4,
          (index) => ImageOption('${index + 1}', '${index + 1}'),
        ),
        onChanged: (String value) => onCountChanged(int.parse(value)),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSelectField<String>(
          label: 'API',
          value: configId,
          options: configs
              .map((config) => (value: config.id, label: config.name))
              .toList(),
          onChanged: onConfigChanged,
        ),
        const SizedBox(height: AppGap.sm),
        for (final field in advancedFields) ...[
          AppSelectField<String>(
            label: field.label,
            value: field.value,
            options: field.options
                .map(
                  (option) => (
                    value: option.value,
                    label: option.label,
                  ),
                )
                .toList(),
            onChanged: field.onChanged,
            emptyPlaceholder: field.label,
          ),
          const SizedBox(height: AppGap.xs),
        ],
      ],
    );
  }
}

class _UploadPanel extends StatelessWidget {
  const _UploadPanel({
    required this.images,
    required this.onPickImages,
    required this.onPreviewImage,
    required this.onRemoveImage,
  });

  final List<ReuseImageFile> images;
  final VoidCallback onPickImages;
  final ValueChanged<int> onPreviewImage;
  final ValueChanged<String> onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadButton.outline(
          onPressed: onPickImages,
          leading: const Icon(LucideIcons.imagePlus),
          child: Text(images.isEmpty ? '选择参考图' : '继续添加 (${images.length}/16)'),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: AppGap.sm),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final image = images[index];
                return SizedBox(
                  width: 92,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _UploadImagePreviewTile(
                          filePath: image.path,
                          onTap: () => onPreviewImage(index),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: ShadIconButton.ghost(
                          height: 24,
                          width: 24,
                          onPressed: () => onRemoveImage(image.path),
                          icon: const Icon(LucideIcons.x),
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: AppGap.sm),
              itemCount: images.length,
            ),
          ),
        ],
      ],
    );
  }
}

class _UploadImagePreviewTile extends StatelessWidget {
  const _UploadImagePreviewTile({required this.filePath, required this.onTap});

  final String filePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: ShadTheme.of(context).colorScheme.background,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cacheWidth = previewCacheExtentFor(
                    context,
                    constraints.maxWidth,
                    min: 92,
                    max: 320,
                  );
                  return Image.file(
                    File(filePath),
                    fit: BoxFit.cover,
                    cacheWidth: cacheWidth,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(LucideIcons.imageOff)),
                  );
                },
              ),
            ),
            const _ImageCardMaskOverlay(),
          ],
        ),
      ),
    );
  }
}

class _ImageCardMaskOverlay extends StatelessWidget {
  const _ImageCardMaskOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
