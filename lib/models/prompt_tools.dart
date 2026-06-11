class PromptApiConfig {
  const PromptApiConfig({
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

  List<String> get modelOptions {
    final seen = <String>{};
    return model
        .split(RegExp(r'[\n,，;；]+'))
        .map((item) => item.trim())
        .where((item) {
          if (item.isEmpty || seen.contains(item)) return false;
          seen.add(item);
          return true;
        })
        .toList(growable: false);
  }

  // 将服务端可能返回的字符串、数组或空值统一转换为模型列表文本。
  static String _readModelText(Object? value) {
    if (value is List) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .join('\n');
    }
    return '${value ?? ''}';
  }

  factory PromptApiConfig.fromJson(Map<String, dynamic> json) {
    return PromptApiConfig(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      baseUrl: '${json['base_url'] ?? ''}',
      model: _readModelText(json['model']),
      createdAt: '${json['created_at'] ?? ''}',
    );
  }
}

class PromptReverseResult {
  const PromptReverseResult({required this.promptEn, required this.promptCn});

  final String promptEn;
  final String promptCn;

  factory PromptReverseResult.fromJson(Map<String, dynamic> json) {
    return PromptReverseResult(
      promptEn: json['prompt_en'] as String? ?? '',
      promptCn: json['prompt_cn'] as String? ?? '',
    );
  }
}

class PromptModifyResult {
  const PromptModifyResult({
    required this.newPromptEn,
    required this.newPromptCn,
  });

  final String newPromptEn;
  final String newPromptCn;

  factory PromptModifyResult.fromJson(Map<String, dynamic> json) {
    return PromptModifyResult(
      newPromptEn: json['new_prompt_en'] as String? ?? '',
      newPromptCn: json['new_prompt_cn'] as String? ?? '',
    );
  }
}
