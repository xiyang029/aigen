import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/prompt_tools.dart';
import '../../services/api_client.dart';
import '../../shared/app_ui.dart';
import '../../shared/image_preview_widgets.dart';
import '../../theme/app_theme.dart';

const _defaultReverseInstruction =
    '请分析这张图片，反推生成它的高细节 AI 绘画提示词。重点描述主体外观、五官表情、视线、动作姿态、服饰材质、道具、背景物品布局、空间层次、构图镜头、光影色彩、氛围风格和渲染质感，不要写成简短摘要。';
const _exampleOriginalPrompt =
    'A cute astronaut cat sitting on a moon base, sipping coffee from a mug, starlit nebula background, digital art style.';
const _exampleEditRequirement = '把猫换成一只正在看书的哈士奇，背景换成温馨的图书馆。';

enum _PromptToolMode { reverse, modify }

class PromptToolsPage extends StatefulWidget {
  const PromptToolsPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<PromptToolsPage> createState() => _PromptToolsPageState();
}

class _PromptToolsPageState extends State<PromptToolsPage> {
  final _reverseInstructionController = TextEditingController(
    text: _defaultReverseInstruction,
  );
  final _originalPromptController = TextEditingController();
  final _editRequirementController = TextEditingController();

  _PromptToolMode _mode = _PromptToolMode.reverse;
  List<PromptApiConfig> _configs = const [
    PromptApiConfig(id: 'default', name: '默认'),
  ];
  String _configId = 'default';
  String _model = '';
  bool _loadingConfigs = true;
  bool _reverseLoading = false;
  bool _modifyLoading = false;
  String? _pickedImagePath;
  PromptReverseResult? _reverseResult;
  PromptModifyResult? _modifyResult;

  bool get _busy => _reverseLoading || _modifyLoading;

  PromptApiConfig? get _selectedConfig {
    for (final config in _configs) {
      if (config.id == _configId) return config;
    }
    return null;
  }

  List<String> get _modelOptions => _selectedConfig?.modelOptions ?? const [];

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  @override
  void dispose() {
    _reverseInstructionController.dispose();
    _originalPromptController.dispose();
    _editRequirementController.dispose();
    super.dispose();
  }

  Future<void> _loadConfigs() async {
    if (mounted) setState(() => _loadingConfigs = true);
    try {
      final configs = await widget.api.fetchPromptConfigs();
      if (!mounted) return;
      final nextConfigs = configs.isEmpty
          ? const [PromptApiConfig(id: 'default', name: '默认')]
          : configs;
      var nextId = _configId;
      if (!nextConfigs.any((config) => config.id == nextId)) {
        nextId = nextConfigs.first.id;
      }
      final selected = nextConfigs.firstWhere(
        (config) => config.id == nextId,
        orElse: () => nextConfigs.first,
      );
      final models = selected.modelOptions;
      setState(() {
        _configs = nextConfigs;
        _configId = nextId;
        if (!models.contains(_model)) {
          _model = models.isEmpty ? '' : models.first;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _loadingConfigs = false);
    }
  }

  void _selectConfig(String value) {
    final config = _configs.firstWhere(
      (item) => item.id == value,
      orElse: () => _configs.first,
    );
    final models = config.modelOptions;
    setState(() {
      _configId = value;
      _model = models.isEmpty ? '' : models.first;
    });
  }

  /// 仅保存本地图片路径，避免选图时同步转码阻塞界面。
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final file = result?.files.firstOrNull;
    final path = file?.path;
    if (file == null || path == null) return;
    if (!mounted) return;
    setState(() {
      _pickedImagePath = path;
      _reverseResult = null;
    });
    showAppToast(context, '图片已载入');
  }

  void _clearImage() {
    setState(() {
      _pickedImagePath = null;
      _reverseResult = null;
    });
  }

  Future<void> _submitReverse() async {
    final model = _model.trim();
    if (model.isEmpty) {
      showAppToast(context, '请先在当前配置中选择模型');
      return;
    }
    final pickedImagePath = _pickedImagePath;
    if ((pickedImagePath ?? '').isEmpty) {
      showAppToast(context, '请选择图片');
      return;
    }
    final imagePath = pickedImagePath!;

    setState(() {
      _reverseLoading = true;
      _reverseResult = null;
    });
    try {
      final imageUrl = await _fileToDataUrl(
        imagePath,
        Uri.file(imagePath).pathSegments.last,
      );
      final result = await widget.api.reversePromptFromImage(
        configId: _configId,
        model: model,
        imageUrl: imageUrl,
        instruction: _reverseInstructionController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _reverseResult = result);
      showAppToast(context, '提示词反推完成');
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _reverseLoading = false);
    }
  }

  Future<void> _submitModify() async {
    final model = _model.trim();
    final originalPrompt = _originalPromptController.text.trim();
    final editRequirement = _editRequirementController.text.trim();
    if (model.isEmpty) {
      showAppToast(context, '请先在当前配置中选择模型');
      return;
    }
    if (originalPrompt.isEmpty) {
      showAppToast(context, '请填写原始提示词');
      return;
    }
    if (editRequirement.isEmpty) {
      showAppToast(context, '请填写修改需求');
      return;
    }

    setState(() {
      _modifyLoading = true;
      _modifyResult = null;
    });
    try {
      final result = await widget.api.modifyPrompt(
        configId: _configId,
        model: model,
        originalPrompt: originalPrompt,
        editRequirement: editRequirement,
      );
      if (!mounted) return;
      setState(() => _modifyResult = result);
      showAppToast(context, '提示词已改写');
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _modifyLoading = false);
    }
  }

  Future<void> _copyText(String value) async {
    final text = value.trim();
    if (text.isEmpty) {
      showAppToast(context, '没有可复制的内容');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showAppToast(context, '已复制到剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      onRefresh: _loadConfigs,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
      children: [
        _HeaderSection(
          configs: _configs,
          selectedConfigId: _configId,
          model: _model,
          modelOptions: _modelOptions,
          loading: _loadingConfigs,
          onRefresh: _loadConfigs,
          onConfigChanged: _selectConfig,
          onModelChanged: (value) => setState(() => _model = value),
        ),
        const SizedBox(height: AppGap.md),
        ShadTabs<_PromptToolMode>(
          value: _mode,
          onChanged: (value) {
            unfocusPrimaryFocus();
            setState(() => _mode = value);
          },
          tabBarConstraints: const BoxConstraints(maxWidth: double.infinity),
          tabs: const [
            ShadTab(
              value: _PromptToolMode.reverse,
              content: SizedBox.shrink(),
              child: _PromptToolTabLabel(
                icon: LucideIcons.scanSearch,
                label: '图片反推',
              ),
            ),
            ShadTab(
              value: _PromptToolMode.modify,
              content: SizedBox.shrink(),
              child: _PromptToolTabLabel(
                icon: LucideIcons.filePenLine,
                label: '提示词修改',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppGap.md),
        if (_mode == _PromptToolMode.reverse)
          _ReversePanel(
            instructionController: _reverseInstructionController,
            pickedImagePath: _pickedImagePath,
            busy: _busy,
            reverseLoading: _reverseLoading,
            onPickImage: _pickImage,
            onClearImage: _clearImage,
            onSubmit: _submitReverse,
          )
        else
          _ModifyPanel(
            originalPromptController: _originalPromptController,
            editRequirementController: _editRequirementController,
            busy: _busy,
            loading: _modifyLoading,
            onSubmit: _submitModify,
          ),
        const SizedBox(height: AppGap.md),
        if (_mode == _PromptToolMode.reverse)
          _ResultSection(
            title: '反推结果',
            blocks: [
              _ResultBlockData(
                title: '英文提示词',
                value: _reverseResult?.promptEn ?? '',
                placeholder: '暂无数据，请先点击上方按钮',
              ),
              _ResultBlockData(
                title: '中文描述',
                value: _reverseResult?.promptCn ?? '',
                placeholder: '暂无数据，请先点击上方按钮',
              ),
            ],
            onCopy: _copyText,
          )
        else
          _ResultSection(
            title: '修改结果',
            blocks: [
              _ResultBlockData(
                title: '新英文提示词',
                value: _modifyResult?.newPromptEn ?? '',
                placeholder: '暂无数据，请先点击上方按钮',
              ),
              _ResultBlockData(
                title: '新中文提示词',
                value: _modifyResult?.newPromptCn ?? '',
                placeholder: '暂无数据，请先点击上方按钮',
              ),
            ],
            onCopy: _copyText,
          ),
      ],
    );
  }
}

class _PromptToolTabLabel extends StatelessWidget {
  const _PromptToolTabLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.configs,
    required this.selectedConfigId,
    required this.model,
    required this.modelOptions,
    required this.loading,
    required this.onRefresh,
    required this.onConfigChanged,
    required this.onModelChanged,
  });

  final List<PromptApiConfig> configs;
  final String selectedConfigId;
  final String model;
  final List<String> modelOptions;
  final bool loading;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onConfigChanged;
  final ValueChanged<String> onModelChanged;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSelectField<String>(
            label: '提示词 API',
            value: selectedConfigId,
            options: configs
                .map((config) => (value: config.id, label: config.name))
                .toList(),
            onChanged: onConfigChanged,
          ),
          const SizedBox(height: AppGap.sm),
          AppSelectField<String>(
            label: '模型',
            value: model,
            options: modelOptions
                .map((item) => (value: item, label: item))
                .toList(),
            onChanged: onModelChanged,
          ),
        ],
      ),
    );
  }
}

class _ReversePanel extends StatelessWidget {
  const _ReversePanel({
    required this.instructionController,
    required this.pickedImagePath,
    required this.busy,
    required this.reverseLoading,
    required this.onPickImage,
    required this.onClearImage,
    required this.onSubmit,
  });

  final TextEditingController instructionController;
  final String? pickedImagePath;
  final bool busy;
  final bool reverseLoading;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ImagePickerPreview(
            pickedImagePath: pickedImagePath,
            onPickImage: onPickImage,
            onClearImage: onClearImage,
          ),
          const SizedBox(height: AppGap.sm),
          ShadTextarea(
            controller: instructionController,
            minHeight: 92,
            maxHeight: 150,
            placeholder: const Text('分析指令'),
          ),
          const SizedBox(height: AppGap.sm),
          ShadButton(
            onPressed: busy ? null : onSubmit,
            leading: reverseLoading
                ? const AppLoadingSpinner(color: Colors.white)
                : const Icon(LucideIcons.sparkles),
            child: Text(reverseLoading ? '正在提交...' : '反推提示词'),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerPreview extends StatelessWidget {
  const _ImagePickerPreview({
    required this.pickedImagePath,
    required this.onPickImage,
    required this.onClearImage,
  });

  final String? pickedImagePath;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    final hasPickedImage = pickedImagePath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadButton.outline(
          onPressed: onPickImage,
          leading: const Icon(LucideIcons.imagePlus),
          child: Text(hasPickedImage ? '重新选择图片' : '选择图片'),
        ),
        const SizedBox(height: AppGap.sm),
        if (hasPickedImage)
          _PickedImagePreviewCard(
            filePath: pickedImagePath!,
            onClearImage: onClearImage,
          )
        else
          const ImagePreviewPlaceholderCard(
            height: 230,
            text: '选择图片后预览',
            leadingIcon: LucideIcons.scanSearch,
          ),
      ],
    );
  }
}

class _PickedImagePreviewCard extends StatelessWidget {
  const _PickedImagePreviewCard({
    required this.filePath,
    required this.onClearImage,
  });

  final String filePath;
  final VoidCallback onClearImage;

  Future<void> _openPreview(BuildContext context) {
    return showImagePreviewOverlay(
      context: context,
      images: [PreviewImageItem(filePath: filePath, heroTag: filePath)],
      headers: const {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 230,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InkWell(
              onTap: () => _openPreview(context),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ShadTheme.of(context).colorScheme.background,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cacheWidth = previewCacheExtentFor(
                      context,
                      constraints.maxWidth,
                      min: 160,
                      max: 960,
                    );
                    return Image.file(
                      File(filePath),
                      fit: BoxFit.cover,
                      cacheWidth: cacheWidth,
                      errorBuilder: (context, error, stackTrace) =>
                          const ImagePreviewEmptyState(text: '图片预览失败'),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: ShadIconButton.ghost(
                onPressed: onClearImage,
                icon: const Icon(LucideIcons.x),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModifyPanel extends StatelessWidget {
  const _ModifyPanel({
    required this.originalPromptController,
    required this.editRequirementController,
    required this.busy,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController originalPromptController;
  final TextEditingController editRequirementController;
  final bool busy;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('原始提示词', style: ShadTheme.of(context).textTheme.muted),
          const SizedBox(height: AppGap.xs),
          ShadTextarea(
            controller: originalPromptController,
            minHeight: 116,
            maxHeight: 210,
            placeholder: const Text(_exampleOriginalPrompt),
          ),
          const SizedBox(height: AppGap.sm),
          Text('修改要求', style: ShadTheme.of(context).textTheme.muted),
          const SizedBox(height: AppGap.xs),
          ShadTextarea(
            controller: editRequirementController,
            minHeight: 92,
            maxHeight: 150,
            placeholder: const Text(_exampleEditRequirement),
          ),
          const SizedBox(height: AppGap.sm),
          ShadButton(
            onPressed: busy ? null : onSubmit,
            leading: loading
                ? const AppLoadingSpinner(color: Colors.white)
                : const Icon(LucideIcons.sparkles),
            child: const Text('生成新提示词'),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.blocks,
    required this.onCopy,
  });

  final String title;
  final List<_ResultBlockData> blocks;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: ShadTheme.of(context).textTheme.h4),
          const SizedBox(height: AppGap.sm),
          for (var index = 0; index < blocks.length; index++) ...[
            if (index > 0) const SizedBox(height: AppGap.sm),
            _ResultBlock(data: blocks[index], onCopy: onCopy),
          ],
        ],
      ),
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({required this.data, required this.onCopy});

  final _ResultBlockData data;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final text = data.value.trim();
    final hasValue = text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(data.title, style: theme.textTheme.small)),
            ShadIconButton.ghost(
              onPressed: hasValue ? () => onCopy(data.value) : null,
              icon: const Icon(LucideIcons.copy),
              iconSize: 18,
              width: 32,
              height: 32,
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 100, maxHeight: 220),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              borderRadius: theme.radius,
              border: Border.all(color: theme.colorScheme.border),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              physics: const ClampingScrollPhysics(),
              child: SelectableText(
                hasValue ? data.value : data.placeholder,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: hasValue ? null : theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultBlockData {
  const _ResultBlockData({
    required this.title,
    required this.value,
    required this.placeholder,
  });

  final String title;
  final String value;
  final String placeholder;
}

Future<String> _fileToDataUrl(String path, String fileName) async {
  final bytes = await File(path).readAsBytes();
  return 'data:${_mimeTypeFromName(fileName)};base64,${base64Encode(bytes)}';
}

String _mimeTypeFromName(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'avif' => 'image/avif',
    'bmp' => 'image/bmp',
    _ => 'image/png',
  };
}
