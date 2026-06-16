import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'app_ui.dart';
import '../theme/app_theme.dart';

class PreviewImageItem {
  const PreviewImageItem({
    this.url,
    this.filePath,
    this.cacheKey = '',
    required this.heroTag,
  }) : assert(url != null || filePath != null);

  final String? url;
  final String? filePath;
  final String cacheKey;
  final Object heroTag;

  bool get isLocalFile => (filePath ?? '').isNotEmpty;
}

Future<void> showImagePreviewOverlay({
  required BuildContext context,
  required List<PreviewImageItem> images,
  required Map<String, String> headers,
  int initialIndex = 0,
  String? Function(int index)? topLabelBuilder,
  Future<void> Function(int index)? onDownloadAt,
}) async {
  if (images.isEmpty) return;
  unfocusPrimaryFocus();
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) =>
          _ImagePreviewOverlayPage(
            images: images,
            headers: headers,
            initialIndex: initialIndex,
            topLabelBuilder: topLabelBuilder,
            onDownloadAt: onDownloadAt,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
  unfocusPrimaryFocus();
}

class _ImagePreviewOverlayPage extends StatefulWidget {
  const _ImagePreviewOverlayPage({
    required this.images,
    required this.headers,
    required this.initialIndex,
    required this.onDownloadAt,
    this.topLabelBuilder,
  });

  final List<PreviewImageItem> images;
  final Map<String, String> headers;
  final int initialIndex;
  final String? Function(int index)? topLabelBuilder;
  final Future<void> Function(int index)? onDownloadAt;

  @override
  State<_ImagePreviewOverlayPage> createState() =>
      _ImagePreviewOverlayPageState();
}

class _ImagePreviewOverlayPageState extends State<_ImagePreviewOverlayPage> {
  late final PageController _pageController;
  late int _index;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrent() async {
    if (_downloading || widget.onDownloadAt == null) return;
    setState(() => _downloading = true);
    try {
      await widget.onDownloadAt!(_index);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topLabel = widget.topLabelBuilder?.call(_index)?.trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PhotoViewGallery.builder(
                pageController: _pageController,
                itemCount: widget.images.length,
                onPageChanged: (value) => setState(() => _index = value),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                loadingBuilder: (context, event) =>
                    const Center(child: AppLoadingSpinner(color: Colors.white)),
                builder: (context, index) {
                  final image = widget.images[index];
                  return PhotoViewGalleryPageOptions(
                    imageProvider: image.isLocalFile
                        ? FileImage(File(image.filePath!))
                        : CachedNetworkImageProvider(
                            image.url!,
                            cacheKey: image.cacheKey,
                            headers: widget.headers,
                          ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 4,
                    heroAttributes: PhotoViewHeroAttributes(tag: image.heroTag),
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        LucideIcons.imageOff,
                        color: Colors.white70,
                        size: 42,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tooltip(
                    message: '关闭',
                    child: ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  if (topLabel.isNotEmpty)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          topLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (widget.onDownloadAt != null)
                    Tooltip(
                      message: _downloading ? '下载中' : '下载',
                      child: ShadIconButton.ghost(
                        icon: _downloading
                            ? const AppLoadingSpinner(
                                size: 20,
                                color: Colors.white,
                              )
                            : const Icon(
                                LucideIcons.download,
                                color: Colors.white,
                              ),
                        onPressed: _downloading ? null : _downloadCurrent,
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Center(
                child: ShadBadge(
                  backgroundColor: Colors.transparent,
                  child: Text(
                    '${_index + 1}/${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImagePreviewFrame extends StatelessWidget {
  const ImagePreviewFrame({
    super.key,
    this.imageUrl,
    this.filePath,
    this.cacheKey = '',
    required this.headers,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.overlay,
    this.errorChild,
    this.placeholderChild,
    this.onTap,
    this.heroTag,
    this.retryVersion = 0,
  }) : assert(imageUrl != null || filePath != null);

  final String? imageUrl;
  final String? filePath;
  final String cacheKey;
  final Map<String, String> headers;
  final BorderRadius borderRadius;
  final Widget? overlay;
  final Widget? errorChild;
  final Widget? placeholderChild;
  final VoidCallback? onTap;
  final Object? heroTag;
  final int retryVersion;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if ((filePath ?? '').isNotEmpty)
            Image.file(
              File(filePath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  errorChild ?? const Center(child: Icon(LucideIcons.imageOff)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final imageUrl = this.imageUrl!;
                final cacheWidth = _cacheExtentFor(
                  context,
                  constraints.maxWidth,
                );
                return CachedNetworkImage(
                  key: ValueKey('$cacheKey#$retryVersion'),
                  imageUrl: imageUrl,
                  cacheKey: cacheKey,
                  httpHeaders: headers,
                  fit: BoxFit.cover,
                  memCacheWidth: cacheWidth,
                  maxWidthDiskCache: cacheWidth,
                  fadeInDuration: const Duration(milliseconds: 90),
                  fadeOutDuration: Duration.zero,
                  errorWidget: (context, url, error) =>
                      errorChild ?? const Center(child: Icon(LucideIcons.imageOff)),
                  placeholder: (context, url) =>
                      placeholderChild ?? const Center(child: AppLoadingSpinner(size: 24)),
                );
              },
            ),
          if (overlay != null) ...[overlay!],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class ImagePreviewCard extends StatelessWidget {
  const ImagePreviewCard({
    super.key,
    this.imageUrl,
    this.filePath,
    this.cacheKey = '',
    required this.headers,
    required this.previewImages,
    required this.initialIndex,
    this.heroTag,
    this.topLabelBuilder,
    this.overlay,
    this.onDownloadAt,
    this.retryVersion = 0,
  }) : assert(imageUrl != null || filePath != null);

  final String? imageUrl;
  final String? filePath;
  final String cacheKey;
  final Map<String, String> headers;
  final List<PreviewImageItem> previewImages;
  final int initialIndex;
  final Future<void> Function(int index)? onDownloadAt;
  final Object? heroTag;
  final String? Function(int index)? topLabelBuilder;
  final Widget? overlay;
  final int retryVersion;

  Future<void> _openPreview(BuildContext context) {
    final images = previewImages.isEmpty
        ? [
            PreviewImageItem(
              url: imageUrl,
              filePath: filePath,
              cacheKey: cacheKey,
              heroTag: heroTag ?? imageUrl ?? filePath!,
            ),
          ]
        : previewImages;
    return showImagePreviewOverlay(
      context: context,
      images: images,
      headers: headers,
      initialIndex: initialIndex,
      topLabelBuilder: topLabelBuilder,
      onDownloadAt: onDownloadAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ImagePreviewFrame(
      imageUrl: imageUrl,
      filePath: filePath,
      cacheKey: cacheKey,
      headers: headers,
      retryVersion: retryVersion,
      overlay: overlay,
      onTap: () => _openPreview(context),
    );
  }
}

class ImagePreviewTitleOverlay extends StatelessWidget {
  const ImagePreviewTitleOverlay({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ImagePreviewPlaceholderCard extends StatelessWidget {
  const ImagePreviewPlaceholderCard({
    super.key,
    this.text = '选择图片或填写 URL 后预览',
    this.leadingIcon = LucideIcons.scanSearch,
    this.height = 230,
    this.action,
  });

  final String text;
  final IconData leadingIcon;
  final double height;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(leadingIcon, size: 42),
                    const SizedBox(height: AppGap.sm),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: ShadTheme.of(context).textTheme.muted,
                    ),
                  ],
                ),
              ),
            ),
            if (action != null) Positioned(right: 8, top: 8, child: action!),
          ],
        ),
      ),
    );
  }
}

int? _cacheExtentFor(BuildContext context, double logicalWidth) {
  if (!logicalWidth.isFinite || logicalWidth <= 0) return null;
  final deviceWidth = logicalWidth * MediaQuery.devicePixelRatioOf(context);
  return deviceWidth.clamp(160, 640).round();
}
