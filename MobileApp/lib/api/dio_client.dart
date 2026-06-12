import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class ApiClient {
  final Dio _dio = Dio();
  final Dio _refreshDio = Dio();
  final _storage = const FlutterSecureStorage();
  static Future<String?>? _refreshing;
  static const _defaultApiBaseUrl = 'http://43.155.162.201/api';

  static Future<void> loadRuntimeConfig() async {}

  // --- 统一服务器 IP 配置 ---
  static String get serverIp {
    const v = String.fromEnvironment('SERVER_IP');
    if (v.isNotEmpty) return v;
    if (kIsWeb) return Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return '43.155.162.201';
    }
    return '43.155.162.201';
  }

  static String get baseUrl {
    const v = String.fromEnvironment('API_BASE_URL');
    if (v.isEmpty) return _defaultApiBaseUrl;
    final normalized = v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    return normalized.endsWith('/api') ? normalized : '$normalized/api';
  }

  static String resolveFileUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return raw;
    final path = raw.startsWith('/') ? raw : '/$raw';
    return Uri.parse(baseUrl).resolve(path).toString();
  }

  // 腾讯云 IM 配置
  static String get tencentIMAppId {
    const v = String.fromEnvironment('TENCENT_IM_APP_ID');
    return v.isNotEmpty ? v : '1600142882';
  }

  Future<String> _getDeviceId() async {
    final existing = await _storage.read(key: 'device_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: 'device_id', value: id);
    return id;
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<String?> _refreshAccessToken() async {
    if (_refreshing != null) return _refreshing!;
    final completer = Completer<String?>();
    _refreshing = completer.future;
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(null);
        return completer.future;
      }

      _refreshDio.options.baseUrl = baseUrl;
      _refreshDio.options.connectTimeout = const Duration(seconds: 10);
      _refreshDio.options.receiveTimeout = const Duration(seconds: 15);
      _refreshDio.options.sendTimeout = const Duration(seconds: 15);

      final resp = await _refreshDio.post('/sessions/refresh', data: {
        'refresh_token': refreshToken,
      });
      if (resp.statusCode == 200 && resp.data['code'] == 200) {
        final newToken = resp.data['data']?['access_token'] as String?;
        if (newToken != null && newToken.isNotEmpty) {
          await _storage.write(key: 'jwt_token', value: newToken);
          final newRefreshToken =
              resp.data['data']?['refresh_token'] as String?;
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await _storage.write(key: 'refresh_token', value: newRefreshToken);
          }
          completer.complete(newToken);
          return completer.future;
        }
      }
      completer.complete(null);
      return completer.future;
    } catch (_) {
      completer.complete(null);
      return completer.future;
    } finally {
      _refreshing = null;
    }
  }

  Future<String?> refreshAccessToken() => _refreshAccessToken();

  ApiClient() {
    reloadOptions();

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['X-Platform'] = _getPlatform();
        options.headers['X-Device-Id'] = await _getDeviceId();
        return handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final req = error.requestOptions;
        final isRefreshCall = req.path.endsWith('/sessions/refresh');
        final alreadyRetried = req.extra['__retried__'] == true;

        if (status == 401 && !isRefreshCall && !alreadyRetried) {
          final newToken = await _refreshAccessToken();
          if (newToken != null && newToken.isNotEmpty) {
            try {
              req.headers['Authorization'] = 'Bearer $newToken';
              req.extra['__retried__'] = true;
              final response = await _dio.fetch(req);
              return handler.resolve(response);
            } catch (e) {
              if (e is DioException) return handler.next(e);
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  void reloadOptions() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    _refreshDio.options.baseUrl = baseUrl;
    _refreshDio.options.connectTimeout = const Duration(seconds: 10);
    _refreshDio.options.receiveTimeout = const Duration(seconds: 15);
    _refreshDio.options.sendTimeout = const Duration(seconds: 15);
  }

  Dio get dio => _dio;
}
