import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ApiClient {
  final Dio _dio = Dio();
  final Dio _refreshDio = Dio();
  final _storage = const FlutterSecureStorage();
  static Future<String?>? _refreshing;
  static const _runtimeApiBaseUrlKey = 'runtime_api_base_url';
  static const _runtimeServerIpKey = 'runtime_server_ip';
  static String? _runtimeApiBaseUrl;
  static String? _runtimeServerIp;

  static Future<void> loadRuntimeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _runtimeApiBaseUrl = prefs.getString(_runtimeApiBaseUrlKey);
    _runtimeServerIp = prefs.getString(_runtimeServerIpKey);
  }

  static Future<void> saveRuntimeApiBaseUrl(String value) async {
    final normalized = normalizeApiBaseUrl(value);
    final prefs = await SharedPreferences.getInstance();
    _runtimeApiBaseUrl = normalized;
    _runtimeServerIp = Uri.parse(normalized).host;
    await prefs.setString(_runtimeApiBaseUrlKey, normalized);
    await prefs.setString(_runtimeServerIpKey, _runtimeServerIp!);
  }

  static String normalizeApiBaseUrl(String value) {
    var raw = value.trim();
    if (raw.isEmpty) return baseUrl;
    final hadScheme = raw.startsWith('http://') || raw.startsWith('https://');
    if (!hadScheme) {
      raw = 'http://$raw';
    }

    var uri = Uri.parse(raw);
    if (uri.host.isEmpty && uri.path.isNotEmpty) {
      uri = Uri.parse('http://$raw');
    }

    var path = uri.path;
    if (path.isEmpty || path == '/') {
      path = '/api';
    } else if (!path.endsWith('/api')) {
      path = path.endsWith('/') ? '${path}api' : '$path/api';
    }

    uri = uri.replace(
      port: uri.hasPort ? uri.port : (hadScheme ? null : 3000),
      path: path,
      query: null,
      fragment: null,
    );
    return uri.toString().replaceFirst(RegExp(r'/$'), '');
  }

  static String _configuredHost() {
    if (_runtimeServerIp != null && _runtimeServerIp!.isNotEmpty) {
      return _runtimeServerIp!;
    }
    if (_runtimeApiBaseUrl != null && _runtimeApiBaseUrl!.isNotEmpty) {
      return Uri.parse(_runtimeApiBaseUrl!).host;
    }
    return serverIp;
  }

  // --- 统一服务器 IP 配置 ---
  // 说明：
  // - 真机(同一 WiFi)：填电脑局域网 IP（如 192.168.1.10）
  // - Android 真机 USB 调试：可先执行 `adb reverse tcp:3000 tcp:3000`，然后用 127.0.0.1
  // - Android 模拟器：通常用 10.0.2.2 访问宿主机（不要用 localhost）
  //
  // 推荐：不要再手改代码，直接用：
  // flutter run --dart-define=SERVER_IP=192.168.1.10
  static String get serverIp {
    if (_runtimeServerIp != null && _runtimeServerIp!.isNotEmpty) {
      return _runtimeServerIp!;
    }
    const v = String.fromEnvironment('SERVER_IP');
    if (v.isNotEmpty) return v;
    if (kIsWeb) return Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return '127.0.0.1';
  }

  static String get baseUrl {
    if (_runtimeApiBaseUrl != null && _runtimeApiBaseUrl!.isNotEmpty) {
      return _runtimeApiBaseUrl!;
    }
    const v = String.fromEnvironment('API_BASE_URL');
    if (v.isEmpty) return 'http://$serverIp:3000/api';
    final normalized = v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    return normalized.endsWith('/api') ? normalized : '$normalized/api';
  }

  // OpenIM 默认地址（当后端未返回配置时作为 fallback）
  static String get openIMApiUrl {
    const v = String.fromEnvironment('OPENIM_API_URL');
    return v.isNotEmpty ? v : 'http://${_configuredHost()}:10002';
  }

  static String get openIMWsUrl {
    const v = String.fromEnvironment('OPENIM_WS_URL');
    return v.isNotEmpty ? v : 'ws://${_configuredHost()}:10001';
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
