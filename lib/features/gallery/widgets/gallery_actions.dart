import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../../services/api_client.dart';
import '../../../shared/app_ui.dart';

Future<void> saveNetworkImageToGallery({
  required BuildContext context,
  required ApiClient api,
  required String url,
  String fileNamePrefix = 'aigen',
}) async {
  try {
    final image = await api.downloadImage(url);
    final baseName = '$fileNamePrefix-${DateTime.now().millisecondsSinceEpoch}';
    final imageFile = File(image.localPath);

    final result = await ImageGallerySaverPlus.saveFile(
      imageFile.path,
      name: baseName,
    );
    final saved = result is Map && result['isSuccess'] == true;
    if (!context.mounted) return;
    showAppToast(context, saved ? '已保存到系统相册' : '保存失败');
  } on ApiException catch (error) {
    if (!context.mounted) return;
    showAppToast(context, error.message);
  } catch (error) {
    if (!context.mounted) return;
    showAppToast(context, '保存失败：${error.toString()}');
  }
}
