import 'package:flutter/material.dart';

import '../../models/image_task.dart';
import '../../models/prompt_tools.dart';
import '../../services/api_client.dart';
import '../../shared/app_ui.dart';

enum _ApiConfigKind {
  image,
  prompt;

  String get label => switch (this) {
    _ApiConfigKind.image => '生图 API',
    _ApiConfigKind.prompt => '提示词 API',
  };

  IconData get icon => switch (this) {
    _ApiConfigKind.image => LucideIcons.sparkles,
    _ApiConfigKind.prompt => LucideIcons.brain,
  };

  String get emptyText => switch (this) {
    _ApiConfigKind.image => '还没有自定义生图 API 配置。',
    _ApiConfigKind.prompt => '还没有自定义提示词 API 配置。',
  };
}

class _EditableConfig {
  const _EditableConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String model;
}

class ApiConfigPage extends StatefulWidget {
  const ApiConfigPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ApiConfigPage> createState() => _ApiConfigPageState();
}

class _ApiConfigPageState extends State<ApiConfigPage> {
  _ApiConfigKind _kind = _ApiConfigKind.image;
  bool _loading = true;
  bool _saving = false;
  List<ImageApiConfig> _imageConfigs = const [];
  List<PromptApiConfig> _promptConfigs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_kind == _ApiConfigKind.image) {
        final configs = await widget.api.fetchImageConfigs(onlyMine: true);
        if (!mounted) return;
        setState(() {
          _imageConfigs = configs.where((config) => !config.isDefault).toList();
        });
      } else {
        final configs = await widget.api.fetchPromptConfigs(onlyMine: true);
        if (!mounted) return;
        setState(() {
          _promptConfigs = configs
              .where((config) => !config.isDefault)
              .toList();
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeKind(_ApiConfigKind value) {
    if (_kind == value) return;
    setState(() => _kind = value);
    _load();
  }

  _EditableConfig _fromImageConfig(ImageApiConfig config) {
    return _EditableConfig(
      id: config.id,
      name: config.name,
      baseUrl: config.baseUrl,
      model: config.model,
    );
  }

  _EditableConfig _fromPromptConfig(PromptApiConfig config) {
    return _EditableConfig(
      id: config.id,
      name: config.name,
      baseUrl: config.baseUrl,
      model: config.model,
    );
  }

  List<_EditableConfig> get _currentConfigs {
    return switch (_kind) {
      _ApiConfigKind.image => _imageConfigs.map(_fromImageConfig).toList(),
      _ApiConfigKind.prompt => _promptConfigs.map(_fromPromptConfig).toList(),
    };
  }

  Future<void> _openEditor([_EditableConfig? config]) async {
    final kind = _kind;
    final result = await showShadSheet<_ConfigFormResult>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (context) => _ConfigEditorSheet(
        kind: kind,
        title: config == null ? '新增${kind.label}配置' : '编辑${kind.label}配置',
        name: config?.name,
        baseUrl: config?.baseUrl,
        model: config?.model,
        isEditing: config != null,
      ),
    );
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await _saveConfig(kind, result, config);
      if (!mounted) return;
      showAppToast(context, '${kind.label}配置已${config == null ? '新增' : '保存'}');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveConfig(
    _ApiConfigKind kind,
    _ConfigFormResult result,
    _EditableConfig? config,
  ) async {
    if (kind == _ApiConfigKind.image) {
      if (config == null) {
        await widget.api.createImageConfig(
          name: result.name,
          baseUrl: result.baseUrl,
          apiKey: result.apiKey,
          model: result.model,
        );
      } else {
        await widget.api.updateImageConfig(
          id: config.id,
          name: result.name,
          baseUrl: result.baseUrl,
          apiKey: result.apiKey.isEmpty ? null : result.apiKey,
          model: result.model,
        );
      }
      return;
    }

    if (config == null) {
      await widget.api.createPromptConfig(
        name: result.name,
        baseUrl: result.baseUrl,
        apiKey: result.apiKey,
        model: result.model,
      );
    } else {
      await widget.api.updatePromptConfig(
        id: config.id,
        name: result.name,
        baseUrl: result.baseUrl,
        apiKey: result.apiKey.isEmpty ? null : result.apiKey,
        model: result.model,
      );
    }
  }

  Future<void> _deleteConfig(_EditableConfig config) async {
    final kind = _kind;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除配置',
      description: '确定删除「${config.name}」吗？正在使用该配置的功能可能无法继续使用。',
      confirmText: '删除',
      confirmIcon: LucideIcons.trash2,
    );
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      if (kind == _ApiConfigKind.image) {
        await widget.api.deleteImageConfig(config.id);
      } else {
        await widget.api.deletePromptConfig(config.id);
      }
      if (!mounted) return;
      showAppToast(context, '${kind.label}配置已删除');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configs = _currentConfigs;
    final hasItems = configs.isNotEmpty;

    return AppPageScaffold(
      onRefresh: _load,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      floatingActionButton: ShadButton(
        onPressed: _saving ? null : () => _openEditor(),
        leading: const Icon(LucideIcons.plus),
        child: const Text('新增配置'),
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadTabs<_ApiConfigKind>(
              value: _kind,
              onChanged: _changeKind,
              tabBarConstraints: const BoxConstraints(
                maxWidth: double.infinity,
              ),
              tabs: const [
                ShadTab(
                  value: _ApiConfigKind.image,
                  content: SizedBox.shrink(),
                  child: AppTabLabel(icon: LucideIcons.sparkles, label: '生图'),
                ),
                ShadTab(
                  value: _ApiConfigKind.prompt,
                  content: SizedBox.shrink(),
                  child: AppTabLabel(icon: LucideIcons.brain, label: '提示词'),
                ),
              ],
            ),
            if (_saving) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!hasItems)
          EmptyState(icon: _kind.icon, text: _kind.emptyText)
        else
          ...configs.map(
            (config) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ConfigTile(
                icon: _kind.icon,
                name: config.name,
                baseUrl: config.baseUrl,
                model: config.model,
                onEdit: () => _openEditor(config),
                onDelete: () => _deleteConfig(config),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfigTile extends StatelessWidget {
  const _ConfigTile({
    required this.icon,
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String name;
  final String baseUrl;
  final String model;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final subtitleLines = <String>[
      if (baseUrl.isNotEmpty) baseUrl,
      if (model.isNotEmpty) '模型：$model',
    ];
    return ShadCard(
      child: Row(
        children: [
          SizedBox.square(
            dimension: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.muted,
                borderRadius: theme.radius,
              ),
              child: Icon(icon),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '未命名配置' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.h4,
                ),
                const SizedBox(height: 4),
                if (subtitleLines.isNotEmpty)
                  Text(
                    subtitleLines.join('\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShadIconButton.ghost(
            onPressed: onEdit,
            icon: const Icon(LucideIcons.pencil),
          ),

          ShadIconButton.ghost(
            onPressed: onDelete,
            icon: const Icon(LucideIcons.trash),
          ),
        ],
      ),
    );
  }
}

class _ConfigEditorSheet extends StatefulWidget {
  const _ConfigEditorSheet({
    required this.kind,
    required this.title,
    required this.isEditing,
    this.name,
    this.baseUrl,
    this.model,
  });

  final _ApiConfigKind kind;
  final String title;
  final bool isEditing;
  final String? name;
  final String? baseUrl;
  final String? model;

  @override
  State<_ConfigEditorSheet> createState() => _ConfigEditorSheetState();
}

class _ConfigEditorSheetState extends State<_ConfigEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;

  bool get _isPrompt => widget.kind == _ApiConfigKind.prompt;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name ?? '');
    _baseUrlController = TextEditingController(text: widget.baseUrl ?? '');
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController(text: widget.model ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final baseUrl = _baseUrlController.text.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    if (name.isEmpty ||
        baseUrl.isEmpty ||
        (!widget.isEditing && apiKey.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写名称、API 地址和密钥')));
      return;
    }
    if (_isPrompt && model.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写提示词模型列表')));
      return;
    }
    Navigator.of(context).pop(
      _ConfigFormResult(
        name: name,
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadSheet(
      title: Text(widget.title),
      closeIcon: const SizedBox.shrink(),
      scrollable: true,
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.only(top: 12),
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return switch (index) {
              0 => ShadInput(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                placeholder: const Text('配置名称'),
                leading: const Icon(LucideIcons.badge, size: 18),
              ),
              1 => ShadInput(
                controller: _baseUrlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                placeholder: const Text('https://api.example.com/v1'),
                leading: const Icon(LucideIcons.link, size: 18),
              ),
              2 => AppObscuredInput(
                controller: _apiKeyController,
                textInputAction: TextInputAction.next,
                placeholder: widget.isEditing ? '新 API Key（留空则不修改）' : 'API Key',
                icon: LucideIcons.keyRound,
              ),
              3 => ShadTextarea(
                controller: _modelController,
                minHeight: _isPrompt ? 92 : 44,
                maxHeight: _isPrompt ? 150 : 76,
                placeholder: Text(
                  _isPrompt ? '模型列表：每行一个或用逗号分隔，例如：gpt-4o' : '模型：留空则使用服务端默认模型',
                ),
              ),
              _ => ShadButton(
                onPressed: _submit,
                leading: const Icon(LucideIcons.save),
                child: Text(widget.isEditing ? '保存配置' : '新增配置'),
              ),
            };
          },
          separatorBuilder: (context, separatorIndex) =>
              const SizedBox(height: 12),
          itemCount: 5,
        ),
      ),
    );
  }
}

class _ConfigFormResult {
  const _ConfigFormResult({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String name;
  final String baseUrl;
  final String apiKey;
  final String model;
}
