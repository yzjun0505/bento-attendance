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

  // --- 统一服务器 IP 配置 ---
  // 说明：
  // - 真机(同一 WiFi)：填电脑局域网 IP（如 192.168.1.10）
  // - Android 真机 USB 调试：可先执行 `adb reverse tcp:3000 tcp:3000`，然后用 127.0.0.1
  // - Android 模拟器：通常用 10.0.2.2 访问宿主机（不要用 localhost）
  //
  // 推荐：不要再手改代码，直接用：
  // flutter run --dart-define=SERVER_IP=192.168.1.10
  static String get serverIp {
    const v = String.fromEnvironment('SERVER_IP');
    if (v.isNotEmpty) return v;
    // 如果在真机/平板上测试，请将此处的 IP 改为你电脑的局域网 IP（如 10.157.202.116）
    // 原来的 10.0.2.2 只适用于 Android 官方模拟器
    return '10.157.202.116'; 
  }

  static String get baseUrl => 'http://$serverIp:3000/api';
  
  // OpenIM 默认地址（当后端未返回配置时作为 fallback）
  static String get openIMApiUrl => 'http://$serverIp:10002';
  static String get openIMWsUrl => 'ws://$serverIp:10001';

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
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);

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

  Dio get dio => _dio;
}
