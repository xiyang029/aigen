import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/image_task.dart';
import '../../services/api_client.dart';
import 'widgets/gallery_actions.dart';
import 'widgets/image_preview_card.dart';
import 'widgets/search_filter_header.dart';
import '../../shared/app_ui.dart';
import '../../theme/app_theme.dart';

class ImageGalleryPage extends StatefulWidget {
  const ImageGalleryPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends State<ImageGalleryPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<ImageGalleryItem> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _cursor;
  ImageMode? _modeFilter;
  int _imageRetryVersion = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadGallery();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 360) {
      _loadGallery(reset: false);
    }
  }

  Future<void> _loadGallery({bool reset = true}) async {
    if (_loading || _loadingMore) return;
    setState(() {
      if (reset) {
        _loading = true;
        _cursor = null;
        _hasMore = true;
        _imageRetryVersion++;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final page = await widget.api.fetchGallery(
        limit: 30,
        cursor: reset ? null : _cursor,
        mode: _modeFilter,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _items = reset ? page.list : [..._items, ...page.list];
        _cursor = page.cursor;
        _hasMore = page.cursor != null && page.list.isNotEmpty;
      });
    } on ApiException catch (error) {
      showAppToast(context, error.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _reload() {
    _searchDebounce?.cancel();
    _loadGallery();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadGallery();
    });
  }

  void _unfocusSearch() {
    unfocusPrimaryFocus();
  }

  Future<void> _downloadImage(ImageGalleryItem item) async {
    await saveNetworkImageToGallery(
      context: context,
      api: widget.api,
      url: item.url,
      fileNamePrefix: 'aigen-gallery',
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewImages = _items
        .map(
          (item) => PreviewImageItem(
            url: widget.api.resolveUrl(item.url).toString(),
            cacheKey: widget.api.cacheKeyForUrl(item.url),
            heroTag: item.id,
          ),
        )
        .toList(growable: false);
    return AppPageScaffold(
      controller: _scrollController,
      onRefresh: () => _loadGallery(),
      children: [
        SearchFilterHeader(
          searchController: _searchController,
          onSearchChanged: _onSearchChanged,
          onUnfocus: _unfocusSearch,
          modeFilter: _modeFilter,
          onModeChanged: (value) {
            _unfocusSearch();
            setState(() => _modeFilter = value);
            _reload();
          },
        ),
        const SizedBox(height: AppGap.sm),
        if (_items.isEmpty)
          EmptyState(
            icon: LucideIcons.grid3x3,
            text: _loading ? '正在加载图片...' : '还没有可展示的完成图片。',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 900
                  ? 5
                  : width >= 640
                  ? 3
                  : 2;
              return GridView.builder(
                itemCount: _items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ImagePreviewCard(
                    imageUrl: widget.api.resolveUrl(item.url).toString(),
                    cacheKey: widget.api.cacheKeyForUrl(item.url),
                    headers: widget.api.authHeaders,
                    previewImages: previewImages,
                    initialIndex: index,
                    retryVersion: _imageRetryVersion,
                    topLabelBuilder: (currentIndex) =>
                        _items[currentIndex].displayUserName,
                    onDownloadAt: (currentIndex) =>
                        _downloadImage(_items[currentIndex]),
                    overlay: ImagePreviewTitleOverlay(
                      title: item.displayUserName,
                    ),
                  );
                },
              );
            },
          ),
        PagingStatusFooter(
          isLoadingMore: _loadingMore,
          hasMore: _hasMore,
          hasItems: _items.isNotEmpty,
        ),
      ],
    );
  }
}
