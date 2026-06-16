import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/image_task.dart';
import '../../services/api_client.dart';
import '../../utils/active_task_poller.dart';
import '../gallery/widgets/search_filter_header.dart';
import 'widgets/task_widgets.dart';
import 'image_task_detail_page.dart';
import '../../shared/app_ui.dart';
import '../../theme/app_theme.dart';

class ImageTaskListPage extends StatefulWidget {
  const ImageTaskListPage({super.key, required this.api, this.onReuseDraft});

  final ApiClient api;
  final ValueChanged<TaskReuseDraft>? onReuseDraft;

  @override
  State<ImageTaskListPage> createState() => _ImageTaskListPageState();
}

class _ImageTaskListPageState extends State<ImageTaskListPage>
    with WidgetsBindingObserver {
  bool _loading = false;
  bool _loadingMore = false;
  bool _resumingTasks = false;
  bool _hasMore = true;
  String? _cursor;
  List<ImageTaskSummary> _tasks = [];
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  ImageMode? _modeFilter;
  Timer? _searchDebounce;
  final _poller = ActiveTaskPoller();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);
    _loadTasks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _tasks.any((task) => task.isActive)) {
      if (mounted) setState(() => _resumingTasks = true);
      _loadTasks(reset: true, silent: true);
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadTasks(reset: false);
    }
  }

  Future<void> _loadTasks({bool reset = true, bool silent = false}) async {
    if (_loading || _loadingMore) return;
    setState(() {
      if (reset) {
        _loading = !silent;
        _cursor = null;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await widget.api.fetchTasks(
        limit: 20,
        cursor: reset ? null : _cursor,
        status: _statusFilter,
        mode: _modeFilter,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _tasks = reset ? page.list : [..._tasks, ...page.list];
        _cursor = page.cursor;
        _hasMore = page.cursor != null && page.list.isNotEmpty;
      });
      _syncPolling();
    } on ApiException catch (error) {
      showAppToast(context, error.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _resumingTasks = false;
        });
      }
    }
  }

  void _unfocusSearch() {
    unfocusPrimaryFocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller.dispose();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _reloadForFilters() {
    _searchDebounce?.cancel();
    _loadTasks(reset: true);
  }

  Future<void> _pollActiveTasks() async {
    try {
      final page = await widget.api.fetchTasks(
        limit: 20,
        status: 'active',
        mode: _modeFilter,
        query: _searchController.text,
      );
      if (!mounted) return;
      final activeById = {for (final task in page.list) task.id: task};
      final hasEndedVisibleTask = _tasks.any(
        (task) => task.isActive && !activeById.containsKey(task.id),
      );
      setState(() {
        _tasks = _tasks
            .map((task) => activeById[task.id] ?? task)
            .toList(growable: false);
      });
      if (hasEndedVisibleTask) {
        await _loadTasks(reset: true, silent: true);
        return;
      }
      _syncPolling();
    } on ApiException catch (error) {
      showAppToast(context, error.message);
    }
  }

  void _syncPolling() {
    _poller.sync(
      shouldPoll: _tasks.any((task) => task.isActive),
      onTick: _pollActiveTasks,
    );
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadTasks(reset: true);
    });
  }

  Future<void> _openTask(ImageTaskSummary task) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => ImageTaskDetailPage(
          api: widget.api,
          taskId: task.id,
          onReuseDraft: widget.onReuseDraft,
        ),
      ),
    );
    if (!mounted) return;
    if (result is TaskReuseDraft) {
      if (widget.onReuseDraft != null) {
        widget.onReuseDraft!(result);
      } else {
        Navigator.of(context).pop(result);
      }
      return;
    }
    await _loadTasks(reset: true);
  }

  Map<String, List<ImageTaskSummary>> _groupTasks(
    List<ImageTaskSummary> tasks,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final groups = <String, List<ImageTaskSummary>>{};
    for (final task in tasks) {
      final parsed = parseImageTaskTime(task.createdAt)?.toLocal();
      final key = switch (parsed) {
        null => '更早',
        final date when DateTime(date.year, date.month, date.day) == today =>
          '今天',
        final date
            when DateTime(date.year, date.month, date.day) == yesterday =>
          '昨天',
        final date =>
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      };
      groups.putIfAbsent(key, () => []).add(task);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groupedTasks = _groupTasks(_tasks);
    return AppPageScaffold(
      controller: _scrollController,
      onRefresh: () => _loadTasks(reset: true),
      children: [
        SearchFilterHeader(
          searchController: _searchController,
          onSearchChanged: _onSearchChanged,
          onUnfocus: _unfocusSearch,
          modeFilter: _modeFilter,
          extraFilters: ShadTabs<String>(
            value: _statusFilter,
            onChanged: (value) {
              _unfocusSearch();
              setState(() => _statusFilter = value);
              _reloadForFilters();
            },
            tabBarConstraints: const BoxConstraints(maxWidth: double.infinity),
            tabs: const [
              ShadTab(
                value: 'all',
                content: SizedBox.shrink(),
                child: AppTabLabel(
                  icon: LucideIcons.grid2x2,
                  label: '全部',
                  iconSize: 14,
                  gap: 3,
                ),
              ),
              ShadTab(
                value: 'active',
                content: SizedBox.shrink(),
                child: AppTabLabel(
                  icon: LucideIcons.refreshCw,
                  label: '进行',
                  iconSize: 14,
                  gap: 3,
                ),
              ),
              ShadTab(
                value: 'completed',
                content: SizedBox.shrink(),
                child: AppTabLabel(
                  icon: LucideIcons.circleCheck,
                  label: '完成',
                  iconSize: 14,
                  gap: 3,
                ),
              ),
              ShadTab(
                value: 'failed',
                content: SizedBox.shrink(),
                child: AppTabLabel(
                  icon: LucideIcons.circleAlert,
                  label: '失败',
                  iconSize: 14,
                  gap: 3,
                ),
              ),
            ],
          ),
          onModeChanged: (value) {
            _unfocusSearch();
            setState(() => _modeFilter = value);
            _reloadForFilters();
          },
        ),
        const SizedBox(height: AppGap.sm),
        if (_tasks.isEmpty)
          EmptyState(
            icon: LucideIcons.images,
            text: _loading
                ? '正在加载任务...'
                : _searchController.text.trim().isNotEmpty ||
                      _statusFilter != 'all' ||
                      _modeFilter != null
                ? '没有匹配的任务，换个筛选条件试试。'
                : '还没有任务，先提交一次生成。',
          )
        else
          ImageTaskGroupedCardList(
            groupedTasks: groupedTasks,
            onTaskTap: _openTask,
            showElapsedLoading: _resumingTasks,
          ),
        PagingStatusFooter(
          isLoadingMore: _loadingMore,
          hasMore: _hasMore,
          hasItems: _tasks.isNotEmpty,
        ),
      ],
    );
  }
}
