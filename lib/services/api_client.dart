import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user.dart';
import '../models/image_task.dart';
import '../models/prompt_tools.dart';
import 'auth_store.dart';

const defaultWorkerBaseUrl = String.fromEnvironment(
  'WORKER_BASE_URL',
  defaultValue: 'https://xy.xiyangs.xyz',
);

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class DownloadedImage {
  const DownloadedImage({
    required this.bytes,
    required this.extension,
    required this.localPath,
  });

  final Uint8List bytes;
  final String extension;
  final String localPath;
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.name,
    required this.body,
    required this.downloadUrl,
    required this.fileName,
    required this.expectedSize,
    required this.sha256,
  });

  final String version;
  final String name;
  final String body;
  final String downloadUrl;
  final String fileName;
  final int expectedSize;
  final String sha256;
}

class _TimedCache<T> {
  const _TimedCache({required this.value, required this.expiresAt});

  final T value;
  final DateTime expiresAt;

  bool get isFresh => DateTime.now().isBefore(expiresAt);
}

class ApiClient {
  ApiClient({AuthStore? authStore, http.Client? httpClient})
    : _authStore = authStore ?? AuthStore(),
      _http = httpClient ?? http.Client();

  final AuthStore _authStore;
  final http.Client _http;
  String _baseUrl = defaultWorkerBaseUrl;
  String? _token;
  _TimedCache<List<ImageApiConfig>>? _configsCache;
  _TimedCache<List<PromptApiConfig>>? _promptConfigsCache;
  _TimedCache<AppReleaseInfo>? _releaseCache;

  static const _configsCacheTtl = Duration(minutes: 5);
  static const _releaseCacheTtl = Duration(minutes: 10);
  static const _releaseApiUrl =
      'https://api.github.com/repos/xiyang029/aigen/releases/latest';
  static const _releaseApkFileName = 'app-arm64-v8a-release.apk';

  String get baseUrl => _baseUrl;
  bool get hasToken => (_token ?? '').isNotEmpty;
  Map<String, String> get authHeaders {
    if ((_token ?? '').isEmpty) return const {};
    return {'Authorization': 'Bearer $_token'};
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = _baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$normalized$path').replace(queryParameters: query);
  }

  Uri resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Uri.parse(url);
    }
    final normalized = _baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$normalized$url');
  }

  String cacheKeyForUrl(String url) {
    final tokenScope = (_token ?? '').isEmpty ? 'public' : _stableHash(_token!);
    return '${_imageCacheIdentity(url)}#$tokenScope';
  }

  String _imageCacheIdentity(String url) {
    final resolved = resolveUrl(url);
    final objectKey = _fileObjectKeyFromUri(resolved);
    if (objectKey != null) return 'image-object:$objectKey';
    return 'image-url:${resolved.toString().length}-${_stableHash(resolved.toString())}';
  }

  String? _fileObjectKeyFromUri(Uri uri) {
    final segments = uri.pathSegments;
    final apiIndex = segments.indexOf('api');
    if (apiIndex < 0 || apiIndex + 1 >= segments.length) return null;
    final resource = segments[apiIndex + 1];
    if (resource != 'file' && resource != 'files') return null;

    final keyStart =
        apiIndex + 2 < segments.length && segments[apiIndex + 2] == 'preview'
        ? apiIndex + 3
        : apiIndex + 2;
    if (keyStart >= segments.length) return null;
    return segments.sublist(keyStart).map(Uri.decodeComponent).join('/');
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<void> load() async {
    _token = await _authStore.readToken();
    _baseUrl =
        (await _authStore.readBaseUrl())?.trim().replaceAll(
          RegExp(r'/+$'),
          '',
        ) ??
        defaultWorkerBaseUrl.replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> updateBaseUrl(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) throw ApiException('请填写 Worker 地址');
    if (_baseUrl != normalized) _clearRuntimeCache();
    _baseUrl = normalized;
    await _authStore.saveBaseUrl(normalized);
  }

  Future<SavedLogin?> readSavedLogin() => _authStore.readLogin();

  Future<void> saveLogin({required String email, required String password}) {
    return _authStore.saveLogin(email: email, password: password);
  }

  Future<void> logout() async {
    _token = null;
    _clearRuntimeCache();
    await _authStore.clearToken();
  }

  Map<String, String> get _jsonHeaders {
    final headers = {'Content-Type': 'application/json'};
    if ((_token ?? '').isNotEmpty) headers['Authorization'] = 'Bearer $_token';
    return headers;
  }

  Future<Map<String, dynamic>> _readJson(http.Response response) async {
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final preview = text.trim().replaceAll(RegExp(r'\s+'), ' ');
      throw ApiException(
        preview.isEmpty
            ? '响应格式无效：HTTP ${response.statusCode}'
            : '响应格式无效：${preview.substring(0, preview.length > 160 ? 160 : preview.length)}',
        response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverMessage = json['error'] ?? json['message'];
      throw ApiException(
        serverMessage is String && serverMessage.trim().isNotEmpty
            ? serverMessage.trim()
            : '网络请求失败：HTTP ${response.statusCode}',
        response.statusCode,
      );
    }
    return json;
  }

  ApiException _networkException(Object error) {
    if (error is http.ClientException ||
        error is SocketException ||
        error is HttpException ||
        error is TimeoutException) {
      return ApiException('网络请求失败');
    }
    return ApiException(error.toString());
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _http.post(
        _uri('/api/app/auth/login'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      );
      final json = await _readJson(response);
      final session = AuthSession.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      );
      _token = session.token;
      await _authStore.saveToken(session.token);
      return session;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _http.post(
        _uri('/api/app/auth/register'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
          'displayName': displayName,
        }),
      );
      final json = await _readJson(response);
      final session = AuthSession.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      );
      _token = session.token;
      await _authStore.saveToken(session.token);
      return session;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final response = await _http.post(
        _uri('/api/app/auth/forgot-password'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email}),
      );
      final json = await _readJson(response);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final message = data['message'];
      return message is String && message.trim().isNotEmpty
          ? message.trim()
          : '验证码已发送，请查看邮箱';
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<AuthSession> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      final response = await _http.post(
        _uri('/api/app/auth/reset-password'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'code': code, 'password': password}),
      );
      final json = await _readJson(response);
      final session = AuthSession.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      );
      _token = session.token;
      await _authStore.saveToken(session.token);
      return session;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<AppUser> me() async {
    try {
      final response = await _http.get(
        _uri('/api/app/auth/me'),
        headers: _jsonHeaders,
      );
      final json = await _readJson(response);
      return AppUser.fromJson(
        (json['data'] as Map<String, dynamic>? ?? {})['user']
                as Map<String, dynamic>? ??
            {},
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<List<ImageApiConfig>> fetchImageConfigs({
    bool onlyMine = false,
  }) async {
    final cached = onlyMine ? null : _configsCache;
    if (cached != null && cached.isFresh) return cached.value;

    try {
      final response = await _http.get(
        _uri('/api/image-configs', onlyMine ? {'scope': 'mine'} : null),
        headers: _jsonHeaders,
      );
      final json = await _readJson(response);
      final configs = <ImageApiConfig>[
        ImageApiConfig.fromJson(json['default'] as Map<String, dynamic>? ?? {}),
        ...(json['data'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ImageApiConfig.fromJson),
      ].where((config) => config.id.isNotEmpty).toList();
      final normalizedConfigs = configs.isEmpty
          ? const [ImageApiConfig(id: 'default', name: '默认')]
          : configs;
      if (!onlyMine) {
        _configsCache = _TimedCache(
          value: normalizedConfigs,
          expiresAt: DateTime.now().add(_configsCacheTtl),
        );
      }
      return normalizedConfigs;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<String> createImageConfig({
    required String name,
    required String baseUrl,
    required String apiKey,
    String? model,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'base_url': baseUrl,
        'api_key': apiKey,
      };
      if ((model ?? '').trim().isNotEmpty) body['model'] = model!.trim();
      final response = await _http.post(
        _uri('/api/image-configs'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      final json = await _readJson(response);
      _configsCache = null;
      return '${(json['data'] as Map<String, dynamic>? ?? {})['id'] ?? ''}';
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<void> updateImageConfig({
    required String id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) async {
    try {
      final body = <String, dynamic>{'id': int.tryParse(id) ?? id};
      if (name != null) body['name'] = name;
      if (baseUrl != null) body['base_url'] = baseUrl;
      if (apiKey != null && apiKey.isNotEmpty) body['api_key'] = apiKey;
      if (model != null && model.isNotEmpty) body['model'] = model;
      final response = await _http.patch(
        _uri('/api/image-configs'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      await _readJson(response);
      _configsCache = null;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<void> deleteImageConfig(String id) async {
    try {
      final response = await _http.delete(
        _uri('/api/image-configs', {'id': id}),
        headers: _jsonHeaders,
      );
      await _readJson(response);
      _configsCache = null;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<AppReleaseInfo> fetchLatestRelease() async {
    final cached = _releaseCache;
    if (cached != null && cached.isFresh) return cached.value;

    try {
      final response = await _http.get(
        Uri.parse(_releaseApiUrl),
        headers: const {
          HttpHeaders.acceptHeader: 'application/vnd.github+json',
          HttpHeaders.userAgentHeader: 'aigen-app-updater',
        },
      );
      final json = await _readJson(response);
      final assets = json['assets'] as List<dynamic>? ?? const [];
      final apkAsset = assets.whereType<Map<String, dynamic>>().firstWhere(
        (asset) => asset['name'] == _releaseApkFileName,
        orElse: () => const {},
      );
      final downloadUrl = apkAsset['browser_download_url'] as String? ?? '';
      if (downloadUrl.isEmpty) {
        throw ApiException('未找到更新包：$_releaseApkFileName');
      }
      final expectedSize = (apkAsset['size'] as num?)?.toInt() ?? 0;
      if (expectedSize <= 0) {
        throw ApiException('更新包大小信息无效');
      }
      final sha256 = _parseReleaseDigest(apkAsset['digest'] as String?);
      if (sha256 == null) {
        throw ApiException('未找到更新包 SHA-256 校验信息');
      }
      final release = AppReleaseInfo(
        version: json['tag_name'] as String? ?? '',
        name: json['name'] as String? ?? '',
        body: json['body'] as String? ?? '',
        downloadUrl: downloadUrl,
        fileName: _releaseApkFileName,
        expectedSize: expectedSize,
        sha256: sha256,
      );
      if (release.version.isEmpty) throw ApiException('更新版本信息无效');
      _releaseCache = _TimedCache(
        value: release,
        expiresAt: DateTime.now().add(_releaseCacheTtl),
      );
      return release;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<ImageTaskSummary> createImageTask({
    required String prompt,
    String negativePrompt = '',
    required ImageMode mode,
    required String configId,
    required String quality,
    required String size,
    required String outputFormat,
    required String moderation,
    required String background,
    required int count,
    List<ReuseImageFile> images = const [],
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/image-generate'));
    if ((_token ?? '').isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.fields.addAll({
      'mode': mode.value,
      'prompt': prompt,
      'negative_prompt': negativePrompt,
      'configId': configId,
      'quality': quality,
      'size': size,
      'output_format': outputFormat,
      'moderation': moderation,
      'background': background,
      'n': count.toString(),
    });
    for (final image in images) {
      request.files.add(await _multipartImage('image', image));
    }

    try {
      final streamed = await _http.send(request);
      final response = await http.Response.fromStream(streamed);
      final json = await _readJson(response);
      return ImageTaskSummary.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<TaskPage> fetchTasks({
    int limit = 20,
    String? cursor,
    String? status,
    ImageMode? mode,
    String? query,
  }) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if ((cursor ?? '').isNotEmpty) params['cursor'] = cursor!;
      if ((status ?? '').isNotEmpty && status != 'all') {
        params['status'] = status!;
      }
      if (mode != null) params['mode'] = mode.value;
      if ((query ?? '').trim().isNotEmpty) params['q'] = query!.trim();
      final response = await _http.get(
        _uri('/api/image-generate/tasks', params),
        headers: _jsonHeaders,
      );
      final json = await _readJson(response);
      return TaskPage.fromJson(json['data'] as Map<String, dynamic>? ?? {});
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<ImageGalleryPageData> fetchGallery({
    int limit = 30,
    String? cursor,
    ImageMode? mode,
    String? query,
  }) async {
    try {
      final params = <String, String>{'limit': limit.toString()};
      if ((cursor ?? '').isNotEmpty) params['cursor'] = cursor!;
      if (mode != null) params['mode'] = mode.value;
      if ((query ?? '').trim().isNotEmpty) params['q'] = query!.trim();
      final response = await _http.get(
        _uri('/api/image-generate/gallery', params),
        headers: _jsonHeaders,
      );
      final json = await _readJson(response);
      return ImageGalleryPageData.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<ImageTaskDetail> fetchTask(String id) async {
    try {
      final response = await _http.get(
        _uri('/api/image-generate/tasks/$id'),
        headers: _jsonHeaders,
      );
      final json = await _readJson(response);
      return ImageTaskDetail.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String password,
  }) async {
    try {
      final response = await _http.post(
        _uri('/api/app/auth/change-password'),
        headers: _jsonHeaders,
        body: jsonEncode({'oldPassword': oldPassword, 'password': password}),
      );
      await _readJson(response);
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<void> retryTask(String id) async {
    try {
      final response = await _http.post(
        _uri('/api/image-generate/tasks/$id', {'action': 'retry'}),
        headers: _jsonHeaders,
      );
      await _readJson(response);
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      final response = await _http.delete(
        _uri('/api/image-generate/tasks/$id'),
        headers: _jsonHeaders,
      );
      await _readJson(response);
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<DownloadedImage> downloadImage(String imageUrl) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(
        resolveUrl(imageUrl).toString(),
        key: cacheKeyForUrl(imageUrl),
        headers: authHeaders,
      );
      return DownloadedImage(
        bytes: await file.readAsBytes(),
        extension: _imageExtensionFromUrl(imageUrl),
        localPath: file.path,
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<File> downloadReleaseApk(
    AppReleaseInfo release, {
    void Function(int receivedBytes, int? totalBytes)? onProgress,
  }) async {
    final file = await _releaseApkFile(release);
    try {
      if (await _isValidReleaseFile(file, release)) {
        onProgress?.call(release.expectedSize, release.expectedSize);
        return file;
      }
      await _deleteIfExists(file);

      final request = http.Request('GET', Uri.parse(release.downloadUrl));
      request.headers[HttpHeaders.userAgentHeader] = 'aigen-app-updater';
      final streamed = await _http.send(request);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw ApiException('下载更新包失败：HTTP ${streamed.statusCode}');
      }
      final expectedTotal = release.expectedSize > 0
          ? release.expectedSize
          : streamed.contentLength;

      final sink = file.openWrite();
      var receivedBytes = 0;
      try {
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress?.call(receivedBytes, expectedTotal);
        }
        await sink.close();
      } catch (_) {
        await sink.close().catchError((_) {});
        await _deleteIfExists(file);
        rethrow;
      }

      if (receivedBytes != release.expectedSize) {
        await _deleteIfExists(file);
        throw ApiException(
          '下载文件大小异常：期望 ${release.expectedSize} 字节，实际 $receivedBytes 字节',
        );
      }

      if (!await _isValidReleaseFile(file, release)) {
        await _deleteIfExists(file);
        throw ApiException('下载包校验失败，请重新下载');
      }

      return file;
    } catch (error) {
      await _deleteCorruptedReleaseFile(file, release);
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<List<PromptApiConfig>> fetchPromptConfigs({
    bool onlyMine = false,
  }) async {
    final cached = onlyMine ? null : _promptConfigsCache;
    if (cached != null && cached.isFresh) return cached.value;

    try {
      final response = await _http.get(
        _uri('/api/prompt-configs', onlyMine ? {'scope': 'mine'} : null),
        headers: _jsonHeaders,
      );
      final json = await _readJson(response);
      final configs = <PromptApiConfig>[
        PromptApiConfig.fromJson(
          json['default'] as Map<String, dynamic>? ?? {},
        ),
        ...(json['data'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(PromptApiConfig.fromJson),
      ].where((config) => config.id.isNotEmpty).toList();
      final normalizedConfigs = configs.isEmpty
          ? const [PromptApiConfig(id: 'default', name: '默认')]
          : configs;
      if (!onlyMine) {
        _promptConfigsCache = _TimedCache(
          value: normalizedConfigs,
          expiresAt: DateTime.now().add(_configsCacheTtl),
        );
      }
      return normalizedConfigs;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<String> createPromptConfig({
    required String name,
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    try {
      final response = await _http.post(
        _uri('/api/prompt-configs'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'name': name,
          'base_url': baseUrl,
          'api_key': apiKey,
          'model': model,
        }),
      );
      final json = await _readJson(response);
      _promptConfigsCache = null;
      return '${(json['data'] as Map<String, dynamic>? ?? {})['id'] ?? ''}';
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<void> updatePromptConfig({
    required String id,
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) async {
    try {
      final body = <String, dynamic>{'id': int.tryParse(id) ?? id};
      if (name != null) body['name'] = name;
      if (baseUrl != null) body['base_url'] = baseUrl;
      if (apiKey != null && apiKey.isNotEmpty) body['api_key'] = apiKey;
      if (model != null) body['model'] = model;
      final response = await _http.patch(
        _uri('/api/prompt-configs'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      await _readJson(response);
      _promptConfigsCache = null;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<void> deletePromptConfig(String id) async {
    try {
      final response = await _http.delete(
        _uri('/api/prompt-configs', {'id': id}),
        headers: _jsonHeaders,
      );
      await _readJson(response);
      _promptConfigsCache = null;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<String> remoteImageBase64(String imageUrl) async {
    try {
      final response = await _http.get(
        _uri('/api/decoder/remote-base64', {'url': imageUrl}),
        headers: _jsonHeaders,
      );
      final json = await _readJson(response);
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final base64 = data['base64'] as String? ?? '';
      if (base64.isEmpty) throw ApiException('图片URL转Base64失败');
      return base64;
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<PromptReverseResult> reversePromptFromImage({
    required String configId,
    required String model,
    required String imageUrl,
    required String instruction,
  }) async {
    try {
      final response = await _http.post(
        _uri('/api/prompt-tools'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'mode': 'reverse',
          'configId': configId,
          'model': model,
          'imageUrl': imageUrl,
          'instruction': instruction,
        }),
      );
      final json = await _readJson(response);
      return PromptReverseResult.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<PromptModifyResult> modifyPrompt({
    required String configId,
    required String model,
    required String originalPrompt,
    required String editRequirement,
  }) async {
    try {
      final response = await _http.post(
        _uri('/api/prompt-tools'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'mode': 'modify',
          'configId': configId,
          'model': model,
          'originalPrompt': originalPrompt,
          'editRequirement': editRequirement,
        }),
      );
      final json = await _readJson(response);
      return PromptModifyResult.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw _networkException(error);
    }
  }

  Future<File> _releaseApkFile(AppReleaseInfo release) async {
    final baseDir =
        await getDownloadsDirectory() ??
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final updateDir = Directory(
      '${baseDir.path}${Platform.pathSeparator}updates',
    );
    await updateDir.create(recursive: true);
    final safeVersion = release.version.replaceAll(
      RegExp(r'[^0-9A-Za-z._-]+'),
      '_',
    );
    final fileName = '$safeVersion-${release.fileName}';
    return File('${updateDir.path}${Platform.pathSeparator}$fileName');
  }

  String? _parseReleaseDigest(String? digestValue) {
    final normalized = (digestValue ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) return normalized;
    final parts = normalized.split(':');
    if (parts.length == 2 &&
        parts.first == 'sha256' &&
        RegExp(r'^[a-f0-9]{64}$').hasMatch(parts.last)) {
      return parts.last;
    }
    return null;
  }

  Future<bool> _isValidReleaseFile(File file, AppReleaseInfo release) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length != release.expectedSize) return false;
    final digest = await _computeFileSha256(file);
    return digest == release.sha256;
  }

  Future<String> _computeFileSha256(File file) async {
    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return output.events.single.toString();
  }

  Future<void> _deleteCorruptedReleaseFile(
    File file,
    AppReleaseInfo release,
  ) async {
    if (!await file.exists()) return;
    if (await _isValidReleaseFile(file, release)) return;
    await _deleteIfExists(file);
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _clearRuntimeCache() {
    _configsCache = null;
    _promptConfigsCache = null;
    _releaseCache = null;
  }

  String _imageExtensionFromUrl(String url) {
    final ext = resolveUrl(url).path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'jpg',
      'webp' => 'webp',
      _ => 'png',
    };
  }

  Future<http.MultipartFile> _multipartImage(
    String field,
    ReuseImageFile file,
  ) {
    return http.MultipartFile.fromPath(
      field,
      file.path,
      filename: file.name,
      contentType: _guessImageMediaType(file.name),
    );
  }

  MediaType _guessImageMediaType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'webp' => MediaType('image', 'webp'),
      'gif' => MediaType('image', 'gif'),
      'avif' => MediaType('image', 'avif'),
      _ => MediaType('image', 'png'),
    };
  }
}
