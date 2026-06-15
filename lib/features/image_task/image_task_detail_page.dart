import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/image_task.dart';
import '../../services/api_client.dart';
import '../../utils/active_task_poller.dart';
import '../gallery/widgets/gallery_actions.dart';
import 'widgets/task_widgets.dart';
import '../../shared/app_ui.dart';

class ImageTaskDetailPage extends StatefulWidget {
  const ImageTaskDetailPage({
    super.key,
    required this.api,
    required this.taskId,
    this.onReuseDraft,
  });

  final ApiClient api;
  final String taskId;
  final ValueChanged<TaskReuseDraft>? onReuseDraft;

  @override
  State<ImageTaskDetailPage> createState() => _ImageTaskDetailPageState();
}

class _ImageTaskDetailPageState extends State<ImageTaskDetailPage>
    with WidgetsBindingObserver {
  ImageTaskDetail? _task;
  final _poller = ActiveTaskPoller();
  bool _loading = true;
  bool _resumingTask = false;
  bool _refreshing = false;
  bool _retrying = false;
  bool _reusing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTask();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _task?.isActive == true) {
      if (mounted) setState(() => _resumingTask = true);
      _loadTask(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller.dispose();
    super.dispose();
  }

  Future<void> _loadTask({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final task = await widget.api.fetchTask(widget.taskId);
      if (!mounted) return;
      setState(() => _task = task);
      _syncPolling(task);
    } on ApiException catch (error) {
      _syncPolling(null);
      showAppToast(context, error.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _resumingTask = false;
        });
      }
    }
  }

  Future<void> _pollTaskSummary() async {
    try {
      final page = await widget.api.fetchTasks(limit: 20, status: 'active');
      if (!mounted) return;
      ImageTaskSummary? matched;
      for (final task in page.list) {
        if (task.id == widget.taskId) {
          matched = task;
          break;
        }
      }
      if (matched == null) {
        await _loadTask(silent: true);
        return;
      }
      final previous = _task;
      final merged =
          previous?.mergeSummary(matched) ??
          ImageTaskDetail.fromSummary(matched);
      setState(() => _task = merged);
      _syncPolling(merged);
    } on ApiException catch (error) {
      _syncPolling(null);
      if (!mounted) return;
      showAppToast(context, error.message);
    }
  }

  void _syncPolling(ImageTaskDetail? task) {
    _poller.sync(shouldPoll: task?.isActive == true, onTick: _pollTaskSummary);
  }

  Future<void> _refreshTask() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _loadTask(silent: true);
      if (!mounted) return;
      showAppToast(context, '任务状态已刷新');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _retryTask() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.api.retryTask(widget.taskId);
      if (!mounted) return;
      showAppToast(context, '已重新提交任务');
      await _loadTask(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _deleteTask() async {
    final task = _task;
    if (task == null) return;
    final confirm = await showAppConfirmDialog(
      context: context,
      title: '删除任务',
      description: '确定删除这个任务吗？',
      confirmText: '删除',
      confirmIcon: LucideIcons.trash2,
    );
    if (!confirm) return;
    try {
      await widget.api.deleteTask(task.id);
      if (!mounted) return;
      showAppToast(context, '任务已删除');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppToast(context, error.message);
    }
  }

  Future<void> _downloadImage(String url) async {
    await saveNetworkImageToGallery(
      context: context,
      api: widget.api,
      url: url,
    );
  }

  Future<void> _reuseTask({required bool asEdit}) async {
    final task = _task;
    if (task == null || _reusing) return;
    final params = task.params;
    if (params == null) {
      showAppToast(context, '当前任务缺少可复用的参数');
      return;
    }

    setState(() => _reusing = true);
    try {
      final reuseImages = <ReuseImageFile>[];
      if (asEdit) {
        final resultImages = task.result?.images ?? const <TaskResultImage>[];
        if (resultImages.isEmpty) {
          showAppToast(context, '当前任务还没有可复用的结果图');
          return;
        }
        final tempDir = await getTemporaryDirectory();
        for (var index = 0; index < resultImages.length; index++) {
          final image = await widget.api.downloadImage(resultImages[index].url);
          final fileName = 'reuse-${task.id}-${index + 1}.${image.extension}';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(image.bytes, flush: true);
          reuseImages.add(ReuseImageFile(name: fileName, path: file.path));
        }
      } else if (task.mode == ImageMode.edit && task.sourceImages.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        for (var index = 0; index < task.sourceImages.length; index++) {
          final sourceImage = task.sourceImages[index];
          final image = await widget.api.downloadImage(sourceImage.url);
          final fileName = sourceImage.name.isNotEmpty
              ? sourceImage.name
              : 'reuse-${task.id}-${index + 1}.${image.extension}';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(image.bytes, flush: true);
          reuseImages.add(ReuseImageFile(name: fileName, path: file.path));
        }
      }

      if (!mounted) return;
      final draft = TaskReuseDraft(
        prompt: asEdit ? '' : task.prompt,
        negativePrompt: asEdit ? '' : task.negativePrompt,
        mode: asEdit ? ImageMode.edit : task.mode,
        quality: params.quality,
        size: params.requestedSize,
        outputFormat: params.outputFormat,
        moderation: params.moderation,
        background: params.background,
        count: params.count,
        images: reuseImages,
      );
      if (widget.onReuseDraft != null) {
        widget.onReuseDraft!(draft);
        if (mounted) Navigator.of(context).pop();
      } else {
        Navigator.of(context).pop(draft);
      }
    } on ApiException catch (error) {
      showAppToast(context, error.message);
    } catch (error) {
      showAppToast(context, '复用失败：${error.toString()}');
    } finally {
      if (mounted) setState(() => _reusing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      onRefresh: _refreshTask,
      children: [
        if (_loading && _task == null)
          Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.6,
            ),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          )
        else if (_task == null)
          const EmptyState(icon: LucideIcons.circleAlert, text: '任务不存在或加载失败。')
        else
          ImageTaskDetailPanel(
            task: _task,
            api: widget.api,
            formatTime: formatImageTaskTime,
            formatElapsedTime: formatImageTaskElapsedTime,
            onRetry: _retryTask,
            onDelete: _deleteTask,
            onDownload: _downloadImage,
            onReuseAsNew: () => _reuseTask(asEdit: false),
            onReuseAsEdit: () => _reuseTask(asEdit: true),
            isRetrying: _retrying,
            isReusing: _reusing,
            showElapsedLoading: _resumingTask,
          ),
      ],
    );
  }
}
