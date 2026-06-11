import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/prompt_tools.dart';
import '../../services/api_client.dart';
import '../../shared/app_ui.dart';

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
  final _imageUrlController = TextEditingController();
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
  bool _convertingUrl = false;
  String? _pickedImagePath;
  String? _pickedImageName;
  String? _pickedImageDataUrl;
  PromptReverseResult? _reverseResult;
  PromptModifyResult? _modifyResult;

  bool get _busy => _reverseLoading || _modifyLoading || _convertingUrl;

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
    _imageUrlController.dispose();
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
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text(error.message)));
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text(error.toString())));
      }
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

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final file = result?.files.firstOrNull;
    final path = file?.path;
    if (file == null || path == null) return;
    try {
      final dataUrl = await _fileToDataUrl(path, file.name);
      if (!mounted) return;
      setState(() {
        _pickedImagePath = path;
        _pickedImageName = file.name;
        _pickedImageDataUrl = dataUrl;
        _imageUrlController.clear();
        _reverseResult = null;
      });
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('图片已载入')));
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        ShadToaster.of(
          context,
        ).show(ShadToast(title: Text('读取图片失败：${error.toString()}')));
      }
    }
  }

  void _clearImage() {
    setState(() {
      _pickedImagePath = null;
      _pickedImageName = null;
      _pickedImageDataUrl = null;
      _reverseResult = null;
    });
  }

  Future<void> _submitReverse() async {
    final model = _model.trim();
    if (model.isEmpty) {
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('请先在当前配置中选择模型')));
      }
      return;
    }
    final imageUrlText = _imageUrlController.text.trim();
    if ((_pickedImageDataUrl ?? '').isEmpty && imageUrlText.isEmpty) {
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('请选择图片或填写图片 URL')));
      }
      return;
    }

    setState(() {
      _reverseLoading = true;
      _reverseResult = null;
    });
    try {
      final imageUrl = await _resolveReverseImageUrl(imageUrlText);
      if (imageUrl.isEmpty) return;
      final result = await widget.api.reversePromptFromImage(
        configId: _configId,
        model: model,
        imageUrl: imageUrl,
        instruction: _reverseInstructionController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _reverseResult = result);
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('提示词反推完成')));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text(error.message)));
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _reverseLoading = false);
    }
  }

  Future<String> _resolveReverseImageUrl(String imageUrlText) async {
    final localDataUrl = _pickedImageDataUrl ?? '';
    if (localDataUrl.isNotEmpty) return localDataUrl;

    Uri resolvedUrl;
    try {
      resolvedUrl = widget.api.resolveUrl(imageUrlText);
    } catch (_) {
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('图片 URL 无效')));
      }
      return '';
    }

    setState(() => _convertingUrl = true);
    try {
      final dataUrl = await widget.api.remoteImageBase64(
        resolvedUrl.toString(),
      );
      if (!mounted) return '';
      setState(() {
        _pickedImageDataUrl = dataUrl;
        _pickedImageName = resolvedUrl.toString();
      });
      return dataUrl;
    } finally {
      if (mounted) setState(() => _convertingUrl = false);
    }
  }

  Future<void> _submitModify() async {
    final model = _model.trim();
    final originalPrompt = _originalPromptController.text.trim();
    final editRequirement = _editRequirementController.text.trim();
    if (model.isEmpty) {
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('请先在当前配置中选择模型')));
      }
      return;
    }
    if (originalPrompt.isEmpty) {
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('请填写原始提示词')));
      }
      return;
    }
    if (editRequirement.isEmpty) {
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('请填写修改需求')));
      }
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
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('提示词已改写')));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text(error.message)));
      }
    } catch (error) {
      if (!mounted) return;
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _modifyLoading = false);
    }
  }

  Future<void> _copyText(String value) async {
    final text = value.trim();
    if (text.isEmpty) {
      if (context.mounted) {
        ShadToaster.of(context).show(ShadToast(title: Text('没有可复制的内容')));
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    if (context.mounted) {
      ShadToaster.of(context).show(ShadToast(title: Text('已复制到剪贴板')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      onRefresh: _loadConfigs,
      onBackgroundTap: () => FocusManager.instance.primaryFocus?.unfocus(),
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
        const SizedBox(height: 14),
        ShadTabs<_PromptToolMode>(
          value: _mode,
          onChanged: (value) {
            FocusManager.instance.primaryFocus?.unfocus();
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
        const SizedBox(height: 14),
        if (_mode == _PromptToolMode.reverse)
          _ReversePanel(
            imageUrlController: _imageUrlController,
            instructionController: _reverseInstructionController,
            pickedImagePath: _pickedImagePath,
            pickedImageName: _pickedImageName,
            api: widget.api,
            busy: _busy,
            reverseLoading: _reverseLoading,
            convertingUrl: _convertingUrl,
            onPickImage: _pickImage,
            onClearImage: _clearImage,
            onSubmit: _submitReverse,
            onImageUrlChanged: (_) => setState(() => _reverseResult = null),
          )
        else
          _ModifyPanel(
            originalPromptController: _originalPromptController,
            editRequirementController: _editRequirementController,
            busy: _busy,
            loading: _modifyLoading,
            onSubmit: _submitModify,
          ),
        const SizedBox(height: 14),
        if (_mode == _PromptToolMode.reverse)
          _ResultSection(
            title: '反推结果',
            blocks: [
              _ResultBlockData(
                title: '英文提示词',
                value: _reverseResult?.promptEn ?? '',
                placeholder: '反推完成后显示英文 AI 绘画提示词。',
              ),
              _ResultBlockData(
                title: '中文描述',
                value: _reverseResult?.promptCn ?? '',
                placeholder: '反推完成后显示中文详细描述。',
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
                placeholder: '改写完成后显示新的英文提示词。',
              ),
              _ResultBlockData(
                title: '新中文提示词',
                value: _modifyResult?.newPromptCn ?? '',
                placeholder: '改写完成后显示新的中文提示词。',
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
          _buildShadSelect<String>(
            context: context,
            label: '提示词 API',
            value: selectedConfigId,
            options: configs
                .map((config) => (value: config.id, label: config.name))
                .toList(),
            onChanged: onConfigChanged,
          ),
          const SizedBox(height: 10),
          _buildShadSelect<String>(
            context: context,
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

Widget _buildShadSelect<T>({
  required BuildContext context,
  required String label,
  required T value,
  required List<({T value, String label})> options,
  required ValueChanged<T> onChanged,
}) {
  final hasOptions = options.isNotEmpty;
  final selectedLabel = options
      .where((option) => option.value == value)
      .map((option) => option.label)
      .firstOrNull;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: ShadTheme.of(context).textTheme.muted),
      const SizedBox(height: 6),
      ShadSelect<T>(
        enabled: hasOptions,
        initialValue: hasOptions ? value : null,
        minWidth: 180,
        placeholder: Text(selectedLabel ?? (hasOptions ? label : '暂无可选项')),
        options: options
            .map(
              (option) =>
                  ShadOption<T>(value: option.value, child: Text(option.label)),
            )
            .toList(),
        selectedOptionBuilder: (_, selectedValue) {
          final selectedOption = options.firstWhere(
            (option) => option.value == selectedValue,
            orElse: () => (value: selectedValue, label: '$selectedValue'),
          );
          return Text(selectedOption.label);
        },
        onChanged: (nextValue) {
          if (nextValue != null) onChanged(nextValue);
        },
      ),
    ],
  );
}

class _ReversePanel extends StatelessWidget {
  const _ReversePanel({
    required this.imageUrlController,
    required this.instructionController,
    required this.pickedImagePath,
    required this.pickedImageName,
    required this.api,
    required this.busy,
    required this.reverseLoading,
    required this.convertingUrl,
    required this.onPickImage,
    required this.onClearImage,
    required this.onSubmit,
    required this.onImageUrlChanged,
  });

  final TextEditingController imageUrlController;
  final TextEditingController instructionController;
  final String? pickedImagePath;
  final String? pickedImageName;
  final ApiClient api;
  final bool busy;
  final bool reverseLoading;
  final bool convertingUrl;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onSubmit;
  final ValueChanged<String> onImageUrlChanged;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            controller: imageUrlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            enabled: pickedImagePath == null && !convertingUrl,
            onChanged: onImageUrlChanged,
            placeholder: const Text('https://example.com/image.jpg'),
            leading: const Icon(LucideIcons.link, size: 18),
          ),
          const SizedBox(height: 12),
          _ImagePickerPreview(
            api: api,
            imageUrlController: imageUrlController,
            pickedImagePath: pickedImagePath,
            pickedImageName: pickedImageName,
            onPickImage: onPickImage,
            onClearImage: onClearImage,
          ),
          const SizedBox(height: 12),
          ShadTextarea(
            controller: instructionController,
            minHeight: 92,
            maxHeight: 150,
            placeholder: const Text('分析指令'),
          ),
          const SizedBox(height: 12),
          ShadButton(
            onPressed: busy ? null : onSubmit,
            leading: reverseLoading || convertingUrl
                ? const AppLoadingSpinner(color: Colors.white)
                : const Icon(LucideIcons.sparkles),
            child: Text(convertingUrl ? '正在读取图片...' : '反推提示词'),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerPreview extends StatelessWidget {
  const _ImagePickerPreview({
    required this.api,
    required this.imageUrlController,
    required this.pickedImagePath,
    required this.pickedImageName,
    required this.onPickImage,
    required this.onClearImage,
  });

  final ApiClient api;
  final TextEditingController imageUrlController;
  final String? pickedImagePath;
  final String? pickedImageName;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    final previewUrl = _resolvedPreviewUrl(api, imageUrlController.text.trim());
    final hasPickedImage = pickedImagePath != null;
    final hasPreview = hasPickedImage || previewUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadButton.outline(
          onPressed: onPickImage,
          leading: const Icon(LucideIcons.imagePlus),
          child: Text(hasPickedImage ? '重新选择图片' : '选择图片'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 230,
          child: Stack(
            children: [
              Positioned.fill(
                child: hasPreview
                    ? _PreviewImage(
                        api: api,
                        filePath: pickedImagePath,
                        url: previewUrl,
                      )
                    : const _ImagePlaceholder(),
              ),
              if (hasPickedImage)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Tooltip(
                    message: '清除图片',
                    child: ShadIconButton.secondary(
                      onPressed: onClearImage,
                      icon: const Icon(LucideIcons.x),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.api, this.filePath, this.url});

  final ApiClient api;
  final String? filePath;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final path = filePath;
    if (path != null) {
      return Image.file(File(path), fit: BoxFit.contain);
    }
    final imageUrl = url;
    if (imageUrl == null) return const _ImagePlaceholder();
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      headers: api.authHeaders,
      errorBuilder: (_, _, _) => const _ImagePlaceholder(text: '图片预览失败'),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: AppLoadingSpinner(size: 28));
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.text = '选择图片或填写 URL 后预览'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.scanSearch, size: 42),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: ShadTheme.of(context).textTheme.muted,
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
          const SizedBox(height: 6),
          ShadTextarea(
            controller: originalPromptController,
            minHeight: 116,
            maxHeight: 210,
            placeholder: const Text(_exampleOriginalPrompt),
          ),
          const SizedBox(height: 12),
          Text('修改要求', style: ShadTheme.of(context).textTheme.muted),
          const SizedBox(height: 6),
          ShadTextarea(
            controller: editRequirementController,
            minHeight: 92,
            maxHeight: 150,
            placeholder: const Text(_exampleEditRequirement),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          for (var index = 0; index < blocks.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
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
            Tooltip(
              message: '复制',
              child: ShadIconButton.ghost(
                onPressed: hasValue ? () => onCopy(data.value) : null,
                icon: const Icon(LucideIcons.copy),
                iconSize: 18,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 116, maxHeight: 240),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              borderRadius: theme.radius,
              border: Border.all(color: theme.colorScheme.border),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
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

String? _resolvedPreviewUrl(ApiClient api, String value) {
  if (value.isEmpty) return null;
  try {
    return api.resolveUrl(value).toString();
  } catch (_) {
    return null;
  }
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
