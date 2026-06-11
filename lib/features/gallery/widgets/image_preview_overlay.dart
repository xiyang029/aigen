import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../../shared/app_ui.dart';


class PreviewImageItem {
  const PreviewImageItem({
    this.url,
    this.filePath,
    this.cacheKey = '',
    required this.heroTag,
  }) : assert(
         (url != null && url != '') || (filePath != null && filePath != ''),
         'PreviewImageItem requires either url or filePath.',
       );

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
  FocusManager.instance.primaryFocus?.unfocus();
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
  FocusManager.instance.primaryFocus?.unfocus();
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

