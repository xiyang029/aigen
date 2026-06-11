import 'package:flutter/material.dart';

import '../../../models/image_task.dart';
import '../../gallery/widgets/image_preview_card.dart';
import '../../../shared/app_ui.dart';

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
          const SizedBox(height: 14),
          const Text('正向提示词'),
          const SizedBox(height: 6),
          ShadTextarea(
            controller: promptController,
            onPressedOutside: (_) => onUnfocus(),
            minHeight: 112,
            maxHeight: 220,
            maxLength: 10000,
            placeholder: const Text('输入要生成的画面、风格、构图和细节'),
          ),
          const SizedBox(height: 10),
          const Text('反向提示词'),
          const SizedBox(height: 6),
          ShadTextarea(
            controller: negativePromptController,
            onPressedOutside: (_) => onUnfocus(),
            minHeight: 84,
            maxHeight: 160,
            maxLength: 10000,
            placeholder: const Text('反向提示词：描述不希望出现的内容，例如低清晰度、变形手指、多余文字'),
          ),
          if (mode == ImageMode.edit) ...[
            const SizedBox(height: 8),
            _UploadPanel(
              images: images,
              onPickImages: onPickImages,
              onPreviewImage: onPreviewImage,
              onRemoveImage: onRemoveImage,
            ),
          ],
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
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
    final stringFields = [
      (
        label: '质量',
        value: quality,
        options: qualityOptions,
        icon: LucideIcons.slidersHorizontal,
        onChanged: onQualityChanged,
      ),
      (
        label: '尺寸',
        value: size,
        options: sizeOptions,
        icon: LucideIcons.ratio,
        onChanged: onSizeChanged,
      ),
      (
        label: '格式',
        value: outputFormat,
        options: outputFormatOptions,
        icon: LucideIcons.image,
        onChanged: onOutputFormatChanged,
      ),
      (
        label: '审核',
        value: moderation,
        options: moderationOptions,
        icon: LucideIcons.shieldCheck,
        onChanged: onModerationChanged,
      ),
      (
        label: '背景',
        value: background,
        options: backgroundOptions,
        icon: LucideIcons.layers,
        onChanged: onBackgroundChanged,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 620;
        return GridView.count(
          crossAxisCount: isWide ? 2 : 1,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 78,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildShadSelect<String>(
              context: context,
              label: 'API',
              value: configId,
              options: configs
                  .map((config) => (value: config.id, label: config.name))
                  .toList(),
              onChanged: onConfigChanged,
            ),
            for (final field in stringFields)
              _buildShadSelect<String>(
                context: context,
                label: field.label,
                value: field.value,
                options: field.options
                    .map((option) => (value: option.value, label: option.label))
                    .toList(),
                onChanged: field.onChanged,
              ),
            _buildShadSelect<int>(
              context: context,
              label: '生成数量',
              value: count,
              options: List.generate(
                4,
                (index) => (value: index + 1, label: '${index + 1}'),
              ),
              onChanged: onCountChanged,
            ),
          ],
        );
      },
    );
  }
}

Widget _buildShadSelect<T>({
  required BuildContext context,
  required String label,
  required T value,
  required List<({T value, String label})> options,
  required ValueChanged<T> onChanged,
}) {
  // 预索引选项文案，避免同一次构建内重复线性扫描。
  final labelsByValue = {
    for (final option in options) option.value: option.label,
  };
  final selectedLabel = labelsByValue[value];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: ShadTheme.of(context).textTheme.muted),
      const SizedBox(height: 6),
      ShadSelect<T>(
        initialValue: value,
        minWidth: 180,
        placeholder: Text(selectedLabel ?? label),
        options: options
            .map(
              (option) =>
                  ShadOption<T>(value: option.value, child: Text(option.label)),
            )
            .toList(),
        selectedOptionBuilder: (_, selectedValue) {
          return Text(labelsByValue[selectedValue] ?? '$selectedValue');
        },
        onChanged: (nextValue) {
          if (nextValue != null) onChanged(nextValue);
        },
      ),
    ],
  );
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
    final previewImages = images
        .map(
          (image) =>
              PreviewImageItem(filePath: image.path, heroTag: image.path),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadButton.outline(
          onPressed: onPickImages,
          leading: const Icon(LucideIcons.imagePlus),
          child: Text(images.isEmpty ? '选择参考图' : '继续添加 (${images.length}/16)'),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 10),
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
                        child: ImagePreviewCard(
                          filePath: image.path,
                          heroTag: image.path,
                          headers: const {},
                          previewImages: previewImages,
                          initialIndex: index,
                          overlay: const _ImageCardMaskOverlay(),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Tooltip(
                          message: '移除图片',
                          child: ShadIconButton.ghost(
                            onPressed: () => onRemoveImage(image.path),
                            icon: const Icon(LucideIcons.x),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: images.length,
            ),
          ),
        ],
      ],
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
