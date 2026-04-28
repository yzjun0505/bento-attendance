import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../api/dio_client.dart';
import '../../models/user_model.dart';
import '../../services/openim_service.dart';
import '../../services/getui_push_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient apiClient;
  final _storage = const FlutterSecureStorage();
  final _imService = OpenIMService();
  final _getuiService = GetuiPushService();
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String? _pendingLogoutError;

  AuthBloc({required this.apiClient}) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<ConnectivityChanged>(_onConnectivityChanged);
    on<LoggedIn>(_onLoggedIn);
    on<LoggedOut>(_onLoggedOut);
    on<UserUpdated>(_onUserUpdated);
    on<IMLoginResult>(_onIMLoginResult);

    _connectivitySub = _connectivity.onConnectivityChanged.listen((r) {
      final online = r.isNotEmpty && !r.contains(ConnectivityResult.none);
      add(ConnectivityChanged(isOnline: online));
    });
  }

  @override
  Future<void> close() async {
    await _connectivitySub?.cancel();
    return super.close();
  }

  Map<String, dynamic> _userToJson(User user) {
    return {
      'id': user.id,
      'username': user.username,
      'name': user.name,
      'role': user.role,
      'phone': user.phone,
      'email': user.email,
      'avatar': user.avatar,
      'project_id': user.projectId,
      'project_name': user.projectName,
    };
  }

  User? _userFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return User.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  User? _userFromJwtToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final id = map['id'];
      if (id == null) return null;
      return User.fromJson({
        'id': id,
        'username': map['username'] ?? '',
        'name': map['name'] ?? map['username'] ?? '用户',
        'role': map['role'] ?? 'worker',
        'phone': null,
        'email': null,
        'avatar': null,
        'project_id': null,
        'project_name': null,
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheUser(User user) async {
    await _storage.write(key: 'user_profile_json', value: jsonEncode(_userToJson(user)));
  }

  Future<void> _clearAuthStorage() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_profile_json');
    await _storage.delete(key: 'last_login_at');
    await _storage.delete(key: 'im_token');
    await _storage.delete(key: 'im_api_addr');
    await _storage.delete(key: 'im_ws_addr');
  }

  Future<void> _logoutOpenIMAndReset() async {
    try {
      await _imService.logout();
      debugPrint('=== OpenIM Logout Success ===');
    } catch (e) {
      debugPrint('=== OpenIM Logout Error: $e ===');
    }
    _imService.reset();
  }

  void _requestLogout({String? error}) {
    _pendingLogoutError = error;
    add(LoggedOut());
  }

  bool _isNetworkError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  Future<void> _asyncValidateProfile(String token) async {
    try {
      final response = await apiClient.dio.get('/auth/profile').timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final user = User.fromJson(response.data['data']);
        await _cacheUser(user);
        add(UserUpdated(user: user));
        return;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        _requestLogout(error: '登录已过期，请重新登录');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _requestLogout(error: '登录已过期，请重新登录');
        return;
      }
      if (_isNetworkError(e)) {
        final currentState = state;
        if (currentState is AuthAuthenticated && currentState.token == token) {
          add(const ConnectivityChanged(isOnline: false));
        }
      }
    } catch (e) {
      debugPrint('Token 验证未知错误: $e');
    }
  }

  Future<bool> _initAndLoginIM(String userID, String imToken, {String? apiAddr, String? wsAddr}) async {
    try {
      debugPrint('=== _initAndLoginIM: userID=$userID, apiAddr=$apiAddr, wsAddr=$wsAddr ===');
      if (!_imService.isInitialized) {
        debugPrint('=== OpenIM SDK 未初始化，开始初始化... ===');
        await _imService.init(apiAddr: apiAddr, wsAddr: wsAddr);
        debugPrint('=== OpenIM SDK 初始化完成 ===');
      } else {
        debugPrint('=== OpenIM SDK 已初始化，跳过 ===');
      }
      debugPrint('=== 开始 OpenIM 登录: userID=$userID ===');
      final success = await _imService.login(userID: userID, token: imToken);
      debugPrint('=== OpenIM Login 结果: $success ===');
      return success;
    } catch (e, stackTrace) {
      debugPrint('=== OpenIM Init/Login Error: $e ===');
      debugPrint('=== StackTrace: $stackTrace ===');
      return false;
    }
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    // 并行读取存储以加快启动速度
    final results = await Future.wait([
      _storage.read(key: 'jwt_token'),
      _storage.read(key: 'user_profile_json'),
      _storage.read(key: 'im_token'),
      _storage.read(key: 'im_api_addr'),
      _storage.read(key: 'im_ws_addr'),
    ]);

    final token = results[0];
    final cachedUserJson = results[1];
    final imToken = results[2];
    String? imApiAddr = results[3];
    String? imWsAddr = results[4];

    // 强制校验缓存的 IM 地址是否与当前环境匹配，如果不匹配（比如从模拟器切换到了真机）则丢弃缓存使用默认
    if (imApiAddr != null && !imApiAddr.contains(ApiClient.serverIp)) {
      imApiAddr = null;
      imWsAddr = null;
    }

    debugPrint('=== AppStarted: jwt=${token != null}, imToken=${imToken != null}, imApiAddr=$imApiAddr, imWsAddr=$imWsAddr ===');
    if (token == null || token.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }

    final cachedUser = _userFromJsonString(cachedUserJson) ?? _userFromJwtToken(token);
    if (cachedUser == null) {
      await _clearAuthStorage();
      await _logoutOpenIMAndReset();
      emit(const AuthUnauthenticated());
      return;
    }

    emit(AuthAuthenticated(
      user: cachedUser,
      token: token,
      imToken: imToken,
      imInitialized: false,
      imConnecting: false,
      isOffline: false,
    ));

    _getuiService.setAlias(cachedUser.id.toString());
    _asyncValidateProfile(token);
    _asyncIMLogin(cachedUser.id.toString(), imToken, apiAddr: imApiAddr, wsAddr: imWsAddr);
  }

  Future<void> _onConnectivityChanged(ConnectivityChanged event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    if (!event.isOnline) {
      if (!currentState.isOffline) {
        emit(currentState.copyWith(isOffline: true));
      }
      return;
    }

    try {
      final response = await apiClient.dio.get('/auth/profile').timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final user = User.fromJson(response.data['data']);
        await _cacheUser(user);
        emit(currentState.copyWith(user: user, isOffline: false));
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _requestLogout(error: '登录已过期，请重新登录');
        return;
      }
      if (_isNetworkError(e)) {
        emit(currentState.copyWith(isOffline: true));
      }
    } catch (e) {
      debugPrint('刷新用户信息未知错误: $e');
    }

    if (currentState.imToken != null && !_imService.isLoggedIn) {
      final imApiAddr = await _storage.read(key: 'im_api_addr');
      final imWsAddr = await _storage.read(key: 'im_ws_addr');
      _asyncIMLogin(currentState.user.id.toString(), currentState.imToken, apiAddr: imApiAddr, wsAddr: imWsAddr);
    } else if (currentState.imToken == null) {
      // 如果没有 imToken，尝试补偿获取
      _compensateIMToken(currentState.user, currentState.token, null);
    }
  }

  Future<void> _onLoggedIn(LoggedIn event, Emitter<AuthState> emit) async {
    debugPrint('=== Login attempt: ${event.username} ===');
    emit(AuthLoading());
    try {
      debugPrint('=== Sending login request to server ===');
      final response = await apiClient.dio.post('/auth/login', data: {
        'username': event.username,
        'password': event.password,
      });

      debugPrint('=== Response status: ${response.statusCode} ===');
      if (response.statusCode == 200) {
        final token = response.data['data']['token'];
        final refreshToken = response.data['data']['refresh_token'];
        final user = User.fromJson(response.data['data']['user']);
        final imToken = response.data['data']['imToken'];

        await _storage.write(key: 'jwt_token', value: token);
        if (refreshToken != null) {
          await _storage.write(key: 'refresh_token', value: refreshToken);
        }
        await _storage.write(key: 'last_login_at', value: DateTime.now().millisecondsSinceEpoch.toString());
        await _cacheUser(user);
        if (imToken != null) {
          await _storage.write(key: 'im_token', value: imToken);
        }

        final imConfig = response.data['data']['imConfig'];
        final bool imAsync = response.data['data']['imAsync'] ?? false;
        
        if (imConfig != null) {
          if (imConfig['apiAddr'] != null) {
            await _storage.write(key: 'im_api_addr', value: imConfig['apiAddr']);
          }
          if (imConfig['wsAddr'] != null) {
            await _storage.write(key: 'im_ws_addr', value: imConfig['wsAddr']);
          }
        }

        debugPrint('=== Login successful, imToken=${imToken != null}, imAsync=$imAsync ===');

        // 核心改动：立即进入主界面
        emit(AuthAuthenticated(
          user: user,
          token: token,
          imToken: imToken,
          imInitialized: false,
          imConnecting: false, 
          isOffline: false,
        ));

        _getuiService.setAlias(user.id.toString());
        // 如果 imToken 是 null 但后端说 imAsync=true，说明后端在处理，我们之后补偿
        if (imToken == null && imAsync) {
          _compensateIMToken(user, token, imConfig);
        } else if (imToken != null) {
          _asyncIMLogin(
            user.id.toString(),
            imToken,
            apiAddr: imConfig?['apiAddr'],
            wsAddr: imConfig?['wsAddr'],
          );
        }
      } else {
        debugPrint('=== Login failed: ${response.data} ===');
        emit(AuthUnauthenticated(error: response.data['message'] ?? '登录失败'));
      }
    } on DioException catch (e) {
      debugPrint('=== DioException: ${e.type} - ${e.message} ===');
      String errorMessage;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = '网络连接超时，请检查网络设置';
          break;
        case DioExceptionType.connectionError:
          errorMessage = '无法连接到服务器，请检查：\n1. 服务器是否已启动\n2. 网络是否正常连接';
          break;
        case DioExceptionType.badResponse:
          if (e.response?.statusCode == 401) {
            errorMessage = '用户名或密码错误';
          } else if (e.response?.statusCode == 500) {
            errorMessage = '服务器内部错误，请联系管理员';
          } else {
            errorMessage = '服务器错误 (${e.response?.statusCode})';
          }
          break;
        default:
          errorMessage = '网络错误，请稍后重试';
      }
      debugPrint('=== Emitting error: $errorMessage ===');
      final errorState = AuthUnauthenticated(error: errorMessage);
      debugPrint(
          '=== Error state created: $errorState, error: ${errorState.error} ===');
      emit(errorState);
      debugPrint('=== Error state emitted ===');
    } catch (e) {
      debugPrint('=== Unknown error: $e ===');
      emit(AuthUnauthenticated(error: '发生未知错误：$e'));
    }
  }

  Future<void> _onLoggedOut(LoggedOut event, Emitter<AuthState> emit) async {
    await _clearAuthStorage();
    await _logoutOpenIMAndReset();
    final error = _pendingLogoutError;
    _pendingLogoutError = null;
    emit(AuthUnauthenticated(error: error));
  }

  // --- 辅助辅助方法 ---

  /// 异步登录 IM（不阻塞 Bloc）
  Future<void> _asyncIMLogin(String userID, String? imToken, {String? apiAddr, String? wsAddr}) async {
    if (imToken == null) {
      // 触发一次补偿逻辑
      add(const ConnectivityChanged(isOnline: true));
      return;
    }
    
    // 延迟 500ms 启动，确保主 UI 已经加载
    await Future.delayed(const Duration(milliseconds: 500));
    
    final success = await _initAndLoginIM(userID, imToken, apiAddr: apiAddr, wsAddr: wsAddr);
    
    add(IMLoginResult(userID: userID, success: success, imToken: imToken));
  }

  Future<void> _onIMLoginResult(IMLoginResult event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is AuthAuthenticated && currentState.user.id.toString() == event.userID) {
      emit(currentState.copyWith(
        imInitialized: event.success,
        imConnecting: false,
        imToken: event.imToken,
      ));
    }
  }

  /// 补偿获取 IM Token
  Future<void> _compensateIMToken(User user, String token, Map<String, dynamic>? imConfig) async {
    try {
      debugPrint('=== 开始补偿获取 IM Token ===');
      // 等待 2 秒给后端异步处理点时间
      await Future.delayed(const Duration(seconds: 2));
      
      final response = await apiClient.dio.get('/auth/im-token');
      if (response.statusCode == 200) {
        final newImToken = response.data['data']['imToken'];
        final newImConfig = response.data['data']['imConfig'] ?? imConfig;
        
        if (newImToken != null) {
          debugPrint('=== 补偿获取 IM Token 成功 ===');
          await _storage.write(key: 'im_token', value: newImToken);
          if (newImConfig != null) {
            await _storage.write(key: 'im_api_addr', value: newImConfig['apiAddr']);
            await _storage.write(key: 'im_ws_addr', value: newImConfig['wsAddr']);
          }
          
          _asyncIMLogin(
            user.id.toString(),
            newImToken,
            apiAddr: newImConfig?['apiAddr'],
            wsAddr: newImConfig?['wsAddr'],
          );
        }
      }
    } catch (e) {
      debugPrint('=== 补偿获取 IM Token 失败: $e ===');
    }
  }

  Future<void> _onUserUpdated(
      UserUpdated event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      emit(currentState.copyWith(user: event.user));
    }
  }
}
