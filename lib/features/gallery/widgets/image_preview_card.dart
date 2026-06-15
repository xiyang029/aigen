import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/app_ui.dart';
import '../../../theme/app_theme.dart';
import 'image_preview_overlay.dart';

export 'image_preview_overlay.dart' show PreviewImageItem;

class ImagePreviewCard extends StatefulWidget {
  ImagePreviewCard({
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
  }) : assert(
         ((imageUrl ?? '').isNotEmpty) || ((filePath ?? '').isNotEmpty),
         'ImagePreviewCard requires either imageUrl or filePath.',
       );

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

  @override
  State<ImagePreviewCard> createState() => _ImagePreviewCardState();
}

class _ImagePreviewCardState extends State<ImagePreviewCard> {
  int _localRetryVersion = 0;
  bool _retrying = false;

  Future<void> _openPreview(BuildContext context) {
    final images = widget.previewImages.isEmpty
        ? [
            PreviewImageItem(
              url: widget.imageUrl,
              filePath: widget.filePath,
              cacheKey: widget.cacheKey,
              heroTag: widget.heroTag ?? widget.imageUrl ?? widget.filePath!,
            ),
          ]
        : widget.previewImages;
    return showImagePreviewOverlay(
      context: context,
      images: images,
      headers: widget.headers,
      initialIndex: widget.initialIndex,
      topLabelBuilder: widget.topLabelBuilder,
      onDownloadAt: widget.onDownloadAt,
    );
  }

  Future<void> _retryImage() async {
    if (_retrying || (widget.imageUrl ?? '').isEmpty) return;
    setState(() => _retrying = true);
    await CachedNetworkImage.evictFromCache(
      widget.imageUrl!,
      cacheKey: widget.cacheKey,
    );
    if (!mounted) return;
    setState(() {
      _localRetryVersion++;
      _retrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openPreview(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if ((widget.filePath ?? '').isNotEmpty)
              Image.file(
                File(widget.filePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(LucideIcons.imageOff)),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final imageUrl = widget.imageUrl!;
                  final cacheWidth = _cacheExtentFor(
                    context,
                    constraints.maxWidth,
                  );
                  return CachedNetworkImage(
                    key: ValueKey(
                      '${widget.cacheKey}#${widget.retryVersion}#$_localRetryVersion',
                    ),
                    imageUrl: imageUrl,
                    cacheKey: widget.cacheKey,
                    httpHeaders: widget.headers,
                    fit: BoxFit.cover,
                    memCacheWidth: cacheWidth,
                    maxWidthDiskCache: cacheWidth,
                    fadeInDuration: const Duration(milliseconds: 90),
                    fadeOutDuration: Duration.zero,
                    errorWidget: (context, url, error) =>
                        _ImageRetryButton(
                          retrying: _retrying,
                          onRetry: _retryImage,
                        ),
                    placeholder: (context, url) => const _ImageTilePlaceholder(),
                  );
                },
              ),
            const IgnorePointer(child: _ImageSurfaceOverlay()),
            ?widget.overlay,
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

class _ImageTilePlaceholder extends StatelessWidget {
  const _ImageTilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Icon(
          LucideIcons.image,
          size: 24,
          color: imageMutedText.withValues(alpha: 0.5),
        ),
    );
  }
}

class _ImageRetryButton extends StatelessWidget {
  const _ImageRetryButton({required this.retrying, required this.onRetry});

  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkResponse(
        onTap: retrying ? null : onRetry,
        radius: 28,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: retrying
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.imageOff),
          ),
        ),
      ),
    );
  }
}

class _ImageSurfaceOverlay extends StatelessWidget {
  const _ImageSurfaceOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: imagePrimaryText.withValues(alpha: 0.12));
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


