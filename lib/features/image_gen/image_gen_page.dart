import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/image_task.dart';
import '../../services/api_client.dart';
import '../../shared/app_update.dart';
import '../../utils/active_task_poller.dart';
import '../../shared/image_preview_widgets.dart';
import '../image_task/image_task_detail_page.dart';
import '../image_task/widgets/task_widgets.dart';
import 'widgets/image_request_sheet.dart';
import '../../shared/app_ui.dart';
import '../../theme/app_theme.dart';

const _defaultNegativePrompt =
    'low quality, blurry, pixelated, jpeg artifacts, deformed anatomy, bad hands, extra fingers, missing fingers, extra limbs, duplicate, cropped, watermark, signature, text';

class ImageGenPage extends StatefulWidget {
  const ImageGenPage({super.key, required this.api, required this.onLogout});

  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<ImageGenPage> createState() => ImageGenPageState();
}

class ImageGenPageState extends State<ImageGenPage>
    with WidgetsBindingObserver {
  final _promptController = TextEditingController();
  final _negativePromptController = TextEditingController(
    text: _defaultNegativePrompt,
  );
  final _scrollController = ScrollController();
  final _poller = ActiveTaskPoller();

  AppUpdateChecker? _updateChecker;
  ImageMode _mode = ImageMode.generate;
  String _configId = 'default';
  String _quality = 'auto';
  String _size = 'auto';
  String _outputFormat = 'png';
  String _moderation = 'auto';
  String _background = 'auto';
  int _count = 1;
  bool _submitting = false;
  bool _loadingTasks = false;
  bool _resumingTasks = false;
  List<ImageApiConfig> _configs = const [
    ImageApiConfig(id: 'default', name: '默认'),
  ];
  List<ReuseImageFile> _images = [];
  List<ImageTaskSummary> _tasks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConfigs();
    _loadTasks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdatesOnLaunch();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateChecker ??= AppUpdateChecker(api: widget.api, context: context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateChecker?.resumePendingInstallIfPossible();
      if (_tasks.any((task) => task.isActive)) {
        if (mounted) setState(() => _resumingTasks = true);
        _loadTasks(silent: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller.dispose();
    _promptController.dispose();
    _negativePromptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _unfocusPrompt() {
    unfocusPrimaryFocus();
  }

  void clearFocus() => _unfocusPrompt();

  Future<void> _checkUpdatesOnLaunch() async {
    await _updateChecker?.check(silentWhenLatest: true, silentError: true);
  }

  Future<bool> _isValidImageFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) return false;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image.width > 0 && frame.image.height > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    final picked = <ReuseImageFile>[];
    var invalidCount = 0;
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      if (await _isValidImageFile(path)) {
        picked.add(ReuseImageFile(name: file.name, path: path));
      } else {
        invalidCount += 1;
      }
    }
    if (!mounted) return;
    if (invalidCount > 0) {
      showAppToast(
        context,
        invalidCount == 1 ? '检测到 1 张损坏图片，已跳过' : '检测到 $invalidCount 张损坏图片，已跳过',
      );
    }
    if (picked.isEmpty) return;
    if (!mounted) return;
    setState(() {
      final existing = _images.map((file) => file.path).toSet();
      _images = [
        ..._images,
        ...picked.where((file) => !existing.contains(file.path)),
      ].take(16).toList();
    });
  }

  Future<void> _previewSelectedImages(int initialIndex) {
    final previewImages = _images
        .map(
          (image) =>
              PreviewImageItem(filePath: image.path, heroTag: image.path),
        )
        .toList(growable: false);
    return showImagePreviewOverlay(
      context: context,
      images: previewImages,
      headers: const {},
      initialIndex: initialIndex,
      topLabelBuilder: (index) => _images[index].name,
    );
  }

  Future<void> _submit() async {
    final prompt = _promptController.text.trim();
    final negativePrompt = _negativePromptController.text.trim();
    if (prompt.isEmpty) {
      showAppToast(context, '请输入正向提示词');
      return;
    }
    if (_mode == ImageMode.edit && _images.isEmpty) {
      showAppToast(context, '图生图模式至少需要 1 张参考图');
      return;
    }
    if (_mode == ImageMode.edit) {
      final invalidImages = <ReuseImageFile>[];
      for (final image in _images) {
        if (!await _isValidImageFile(image.path)) invalidImages.add(image);
      }
      if (invalidImages.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          final invalidPaths = invalidImages.map((item) => item.path).toSet();
          _images = _images
              .where((image) => !invalidPaths.contains(image.path))
              .toList();
        });
        showAppToast(
          context,
          invalidImages.length == 1
              ? '检测到 1 张损坏图片，已从列表移除，请重新提交'
              : '检测到 ${invalidImages.length} 张损坏图片，已从列表移除，请重新提交',
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final task = await widget.api.createImageTask(
        prompt: prompt,
        negativePrompt: negativePrompt,
        mode: _mode,
        configId: _configId,
        quality: _quality,
        size: _size,
        outputFormat: _outputFormat,
        moderation: _moderation,
        background: _background,
        count: _count,
        images: _mode == ImageMode.edit ? _images : const [],
      );
      if (!mounted) return;
      showAppToast(context, '任务已提交');
      setState(() {
        _tasks = task.isActive
            ? [task, ..._tasks.where((item) => item.id != task.id)]
            : _tasks.where((item) => item.id != task.id).toList();
      });
      _syncPolling();
      await _loadTasks(silent: true);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _handleUnauthorized();
      if (!mounted) return;
      showAppToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showAppToast(context, error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadTasks({bool silent = false}) async {
    if (_loadingTasks) return;
    if (!silent && mounted) setState(() => _loadingTasks = true);
    try {
      final page = await widget.api.fetchTasks(status: 'active');
      if (!mounted) return;
      setState(() {
        _tasks = page.list;
      });
      _syncPolling();
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _handleUnauthorized();
    } finally {
      if (mounted) {
        setState(() {
          _loadingTasks = false;
          _resumingTasks = false;
        });
      }
    }
  }

  Future<void> _loadConfigs() async {
    try {
      final configs = await widget.api.fetchImageConfigs();
      if (!mounted) return;
      setState(() {
        _configs = configs;
        if (!_configs.any((config) => config.id == _configId)) {
          _configId = _configs.first.id;
        }
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _handleUnauthorized();
      } else {
        if (!mounted) return;
        showAppToast(context, error.message);
      }
    }
  }

  Future<void> _handleUnauthorized() async {
    await widget.api.logout();
    if (!mounted) return;
    widget.onLogout();
  }

  void _syncPolling() {
    _poller.sync(
      shouldPoll: _tasks.any((task) => task.isActive),
      onTick: () => _loadTasks(silent: true),
    );
  }

  Future<void> _openTaskDetail(ImageTaskSummary task) async {
    _unfocusPrompt();
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => ImageTaskDetailPage(
          api: widget.api,
          taskId: task.id,
          onReuseDraft: applyReuseDraft,
        ),
      ),
    );
    if (!mounted) return;
    if (result is TaskReuseDraft) {
      applyReuseDraft(result);
      return;
    }
    await _loadTasks(silent: true);
  }

  void applyReuseDraft(TaskReuseDraft draft) {
    _unfocusPrompt();
    _promptController.text = draft.prompt;
    _negativePromptController.text = draft.negativePrompt.isEmpty
        ? _defaultNegativePrompt
        : draft.negativePrompt;
    setState(() {
      _mode = draft.mode;
      _quality = draft.quality.isEmpty ? _quality : draft.quality;
      _size = draft.size.isEmpty ? _size : draft.size;
      _outputFormat = draft.outputFormat.isEmpty
          ? _outputFormat
          : draft.outputFormat;
      _moderation = draft.moderation.isEmpty ? _moderation : draft.moderation;
      _background = draft.background.isEmpty ? _background : draft.background;
      _count = draft.count;
      _images = draft.images
          .map((image) => ReuseImageFile(name: image.name, path: image.path))
          .toList();
    });
    showAppToast(
      context,
      draft.mode == ImageMode.edit ? '已套用结果图和参数' : '已套用提示词和参数',
    );
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      controller: _scrollController,
      onRefresh: _loadTasks,
      children: [
        ImageRequestSheet(
          mode: _mode,
          promptController: _promptController,
          negativePromptController: _negativePromptController,
          configId: _configId,
          configs: _configs,
          quality: _quality,
          size: _size,
          outputFormat: _outputFormat,
          moderation: _moderation,
          background: _background,
          count: _count,
          images: _images,
          submitting: _submitting,
          onUnfocus: _unfocusPrompt,
          onModeChanged: (value) {
            unfocusPrimaryFocus();
            setState(() => _mode = value);
          },
          onPickImages: () {
            _unfocusPrompt();
            _pickImages();
          },
          onPreviewImage: _previewSelectedImages,
          onRemoveImage: (path) {
            _unfocusPrompt();
            setState(() {
              _images = _images.where((file) => file.path != path).toList();
            });
          },
          onConfigChanged: (value) => setState(() => _configId = value),
          onQualityChanged: (value) => setState(() => _quality = value),
          onSizeChanged: (value) => setState(() => _size = value),
          onOutputFormatChanged: (value) =>
              setState(() => _outputFormat = value),
          onModerationChanged: (value) => setState(() => _moderation = value),
          onBackgroundChanged: (value) => setState(() => _background = value),
          onCountChanged: (value) => setState(() => _count = value),
          onSubmit: _submit,
        ),
        const SizedBox(height: AppGap.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('进行中', style: TextStyle(fontWeight: FontWeight.bold)),
            ShadBadge(child: Text('活跃 ${_tasks.length}')),
          ],
        ),
        const SizedBox(height: AppGap.sm),
        if (_tasks.isEmpty)
          EmptyState(
            icon: LucideIcons.images,
            text: _loadingTasks ? '正在加载任务...' : '当前没有运行中的任务。',
          )
        else
          ImageTaskCardList(
            tasks: _tasks,
            onTaskTap: _openTaskDetail,
            showElapsedLoading: _resumingTasks,
          ),
      ],
    );
  }
}
