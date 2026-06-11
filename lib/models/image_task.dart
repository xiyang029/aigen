enum ImageMode {
  generate,
  edit;

  String get value => switch (this) {
    ImageMode.generate => 'generate',
    ImageMode.edit => 'edit',
  };

  String get label => switch (this) {
    ImageMode.generate => '文生图',
    ImageMode.edit => '图生图',
  };

  static ImageMode fromValue(String value) {
    return value == 'edit' ? ImageMode.edit : ImageMode.generate;
  }
}

class GenerationMeta {
  const GenerationMeta({
    required this.requestedSize,
    required this.quality,
    required this.outputFormat,
    required this.moderation,
    required this.background,
    required this.count,
  });

  final String requestedSize;
  final String quality;
  final String outputFormat;
  final String moderation;
  final String background;
  final int count;

  factory GenerationMeta.fromJson(Map<String, dynamic> json) {
    return GenerationMeta(
      requestedSize: json['requestedSize'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      outputFormat: json['outputFormat'] as String? ?? '',
      moderation: json['moderation'] as String? ?? '',
      background: json['background'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
    );
  }
}

class TaskResultImage {
  const TaskResultImage({required this.url});

  final String url;

  factory TaskResultImage.fromJson(Map<String, dynamic> json) {
    return TaskResultImage(url: json['url'] as String? ?? '');
  }
}

class TaskResult {
  const TaskResult({required this.images});

  final List<TaskResultImage> images;

  factory TaskResult.fromJson(Map<String, dynamic> json) {
    return TaskResult(
      images: (json['images'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TaskResultImage.fromJson)
          .toList(),
    );
  }
}

class ImageTaskSummary {
  const ImageTaskSummary({
    required this.id,
    required this.status,
    required this.mode,
    required this.prompt,
    this.negativePrompt = '',
    required this.createdAt,
    this.finishedAt,
    this.errorMessage,
  });

  final String id;
  final String status;
  final ImageMode mode;
  final String prompt;
  final String negativePrompt;
  final String createdAt;
  final String? finishedAt;
  final String? errorMessage;

  bool get isActive => status == 'queued' || status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory ImageTaskSummary.fromJson(Map<String, dynamic> json) {
    return ImageTaskSummary(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'queued',
      mode: ImageMode.fromValue(json['mode'] as String? ?? 'generate'),
      prompt: json['prompt'] as String? ?? '',
      negativePrompt: json['negativePrompt'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      finishedAt: json['finishedAt'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class ImageTaskDetail extends ImageTaskSummary {
  const ImageTaskDetail({
    required super.id,
    required super.status,
    required super.mode,
    required super.prompt,
    super.negativePrompt,
    required super.createdAt,
    super.finishedAt,
    super.errorMessage,
    this.params,
    this.sourceImages = const [],
    this.result,
  });

  final GenerationMeta? params;
  final List<TaskSourceImage> sourceImages;
  final TaskResult? result;

  factory ImageTaskDetail.fromJson(Map<String, dynamic> json) {
    return ImageTaskDetail(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'queued',
      mode: ImageMode.fromValue(json['mode'] as String? ?? 'generate'),
      prompt: json['prompt'] as String? ?? '',
      negativePrompt: json['negativePrompt'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      finishedAt: json['finishedAt'] as String?,
      errorMessage: json['errorMessage'] as String?,
      params: json['params'] == null
          ? null
          : GenerationMeta.fromJson(
              json['params'] as Map<String, dynamic>? ?? {},
            ),
      sourceImages: (json['sourceImages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TaskSourceImage.fromJson)
          .where((item) => item.url.isNotEmpty)
          .toList(),
      result: json['result'] == null
          ? null
          : TaskResult.fromJson(json['result'] as Map<String, dynamic>? ?? {}),
    );
  }

  factory ImageTaskDetail.fromSummary(ImageTaskSummary summary) {
    return ImageTaskDetail(
      id: summary.id,
      status: summary.status,
      mode: summary.mode,
      prompt: summary.prompt,
      negativePrompt: summary.negativePrompt,
      createdAt: summary.createdAt,
      finishedAt: summary.finishedAt,
      errorMessage: summary.errorMessage,
    );
  }

  ImageTaskDetail mergeSummary(ImageTaskSummary summary) {
    return ImageTaskDetail(
      id: summary.id,
      status: summary.status,
      mode: summary.mode,
      prompt: summary.prompt,
      negativePrompt: summary.negativePrompt,
      createdAt: summary.createdAt,
      finishedAt: summary.finishedAt,
      errorMessage: summary.errorMessage,
      params: params,
      sourceImages: sourceImages,
      result: result,
    );
  }
}

class TaskSourceImage {
  const TaskSourceImage({
    required this.url,
    required this.name,
    required this.contentType,
  });

  final String url;
  final String name;
  final String contentType;

  factory TaskSourceImage.fromJson(Map<String, dynamic> json) {
    return TaskSourceImage(
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
    );
  }
}

class TaskReuseDraft {
  const TaskReuseDraft({
    required this.prompt,
    this.negativePrompt = '',
    required this.mode,
    required this.quality,
    required this.size,
    required this.outputFormat,
    required this.moderation,
    required this.background,
    required this.count,
    this.images = const [],
  });

  final String prompt;
  final String negativePrompt;
  final ImageMode mode;
  final String quality;
  final String size;
  final String outputFormat;
  final String moderation;
  final String background;
  final int count;
  final List<ReuseImageFile> images;
}

class ReuseImageFile {
  const ReuseImageFile({required this.name, required this.path});

  final String name;
  final String path;
}

class TaskStats {
  const TaskStats({
    this.total = 0,
    this.active = 0,
    this.completed = 0,
    this.failed = 0,
    this.generate = 0,
    this.edit = 0,
  });

  final int total;
  final int active;
  final int completed;
  final int failed;
  final int generate;
  final int edit;

  factory TaskStats.fromJson(Map<String, dynamic> json) {
    return TaskStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      generate: (json['generate'] as num?)?.toInt() ?? 0,
      edit: (json['edit'] as num?)?.toInt() ?? 0,
    );
  }
}

class TaskPage {
  const TaskPage({
    required this.list,
    this.cursor,
    this.total = 0,
    this.stats = const TaskStats(),
  });

  final List<ImageTaskSummary> list;
  final String? cursor;
  final int total;
  final TaskStats stats;

  factory TaskPage.fromJson(Map<String, dynamic> json) {
    return TaskPage(
      list: (json['list'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ImageTaskSummary.fromJson)
          .toList(),
      cursor: json['cursor'] as String?,
      total: (json['total'] as num?)?.toInt() ?? 0,
      stats: TaskStats.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class ImageGalleryItem {
  const ImageGalleryItem({
    required this.id,
    required this.taskId,
    required this.url,
    required this.prompt,
    this.negativePrompt = '',
    required this.mode,
    required this.createdAt,
    this.finishedAt,
    this.userId,
    this.userName,
  });

  final String id;
  final String taskId;
  final String url;
  final String prompt;
  final String negativePrompt;
  final ImageMode mode;
  final String createdAt;
  final String? finishedAt;
  final String? userId;
  final String? userName;

  String get displayUserName {
    final name = (userName ?? '').trim();
    if (name.isNotEmpty) return name;
    final id = (userId ?? '').trim();
    if (id.isNotEmpty) {
      return id.length > 8 ? '用户 ${id.substring(0, 8)}' : '用户 $id';
    }
    return '管理员';
  }

  factory ImageGalleryItem.fromJson(Map<String, dynamic> json) {
    return ImageGalleryItem(
      id: json['id'] as String? ?? '',
      taskId: json['taskId'] as String? ?? '',
      url: json['url'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      negativePrompt: json['negativePrompt'] as String? ?? '',
      mode: ImageMode.fromValue(json['mode'] as String? ?? 'generate'),
      createdAt: json['createdAt'] as String? ?? '',
      finishedAt: json['finishedAt'] as String?,
      userId: json['userId'] as String?,
      userName: json['userName'] as String?,
    );
  }
}

class ImageGalleryPageData {
  const ImageGalleryPageData({required this.list, this.cursor, this.total = 0});

  final List<ImageGalleryItem> list;
  final String? cursor;
  final int total;

  factory ImageGalleryPageData.fromJson(Map<String, dynamic> json) {
    return ImageGalleryPageData(
      list: (json['list'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ImageGalleryItem.fromJson)
          .where((item) => item.url.isNotEmpty)
          .toList(),
      cursor: json['cursor'] as String?,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class ImageOption {
  const ImageOption(this.value, this.label);

  final String value;
  final String label;
}

class ImageApiConfig {
  const ImageApiConfig({
    required this.id,
    required this.name,
    this.baseUrl = '',
    this.model = '',
    this.createdAt = '',
  });

  final String id;
  final String name;
  final String baseUrl;
  final String model;
  final String createdAt;

  bool get isDefault => id == 'default';

  factory ImageApiConfig.fromJson(Map<String, dynamic> json) {
    return ImageApiConfig(
      id: '${json['id'] ?? ''}',
      name: json['name'] as String? ?? '',
      baseUrl: json['base_url'] as String? ?? '',
      model: json['model'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

const sizeOptions = [
  ImageOption('auto', '自动'),
  ImageOption('1024x1024', '正方形 1024 x 1024'),
  ImageOption('1536x1024', '横版 1536 x 1024'),
  ImageOption('1024x1536', '竖版 1024 x 1536'),
  ImageOption('2048x2048', '大正方形 2048 x 2048'),
  ImageOption('2048x1152', '宽屏 2048 x 1152'),
  ImageOption('2160x3840', '超竖屏 2160 x 3840'),
  ImageOption('3840x2160', '超宽屏 3840 x 2160'),
];

const qualityOptions = [
  ImageOption('auto', '自动'),
  ImageOption('low', '低'),
  ImageOption('medium', '中'),
  ImageOption('high', '高'),
];

const outputFormatOptions = [
  ImageOption('png', 'PNG'),
  ImageOption('jpeg', 'JPEG'),
  ImageOption('webp', 'WebP'),
];

const moderationOptions = [ImageOption('auto', '自动'), ImageOption('low', '低')];

const backgroundOptions = [
  ImageOption('auto', '自动'),
  ImageOption('opaque', '不透明'),
];
