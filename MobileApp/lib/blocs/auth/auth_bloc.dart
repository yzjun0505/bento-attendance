import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:tuikit_atomic_x/atomicx.dart';
import '../../api/dio_client.dart';
import '../../models/user_model.dart';
import '../../services/tencent_im_service.dart';
import '../../services/tuikit_config.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient apiClient;
  final _storage = const FlutterSecureStorage();
  final _imService = TencentIMService();
  final _connectivity = Connectivity();
  static const int _maxIMLoginAttempts = 3;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String? _pendingLogoutError;
  Future<void>? _imLoginTask;
  Future<void>? _imRefreshTask;
  String? _activeIMLoginKey;
  String? _activeIMRefreshUserID;
  int _imLoginGeneration = 0;
  int _imLoginAttempts = 0;

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
    await _storage.write(
        key: 'user_profile_json', value: jsonEncode(_userToJson(user)));
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

  Future<void> _logoutTencentIMAndReset() async {
    _imLoginGeneration++;
    _imLoginAttempts = 0;
    _activeIMLoginKey = null;
    _activeIMRefreshUserID = null;
    try {
      await LoginStore.shared.logout();
      debugPrint('=== 腾讯云 IM (TUIKit) Logout Success ===');
    } catch (e) {
      debugPrint('=== 腾讯云 IM Logout Error: $e ===');
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

  bool _isStaleIMToken(String? token) {
    return token == null || token.isEmpty || token.startsWith('mock_im_token_');
  }

  Future<void> _clearIMStorage() async {
    await _storage.delete(key: 'im_token');
    await _storage.delete(key: 'im_api_addr');
    await _storage.delete(key: 'im_ws_addr');
  }

  Future<void> _asyncValidateProfile(String token) async {
    try {
      final response = await apiClient.dio
          .get('/auth/profile')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final user = User.fromJson(response.data['data']);
        final latestToken = await _storage.read(key: 'jwt_token') ?? token;
        await _cacheUser(user);
        add(UserUpdated(user: user, token: latestToken));
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

  Future<bool> _initAndLoginIM(String userID, String userSig) async {
    try {
      debugPrint('=== _initAndLoginIM (TUIKit LoginStore): userID=$userID ===');

      final loginState = LoginStore.shared.loginState;
      if (loginState.loginStatus == LoginStatus.logined &&
          loginState.loginUserInfo?.userID == userID) {
        debugPrint('=== TUIKit 已登录当前用户，跳过重复登录 ===');
        _imService.markLoggedIn(userID);
        return true;
      }

      // 通过 TUIKit 的 LoginStore 登录，这样 TUIKit 的 UI 组件
      // （ConversationsPage、ChatPage 等）才能感知到登录状态并正常渲染
      final result = await LoginStore.shared.login(
        sdkAppID: kTencentIMAppId,
        userID: userID,
        userSig: userSig,
      );

      if (result.errorCode == 0) {
        debugPrint('=== TUIKit LoginStore 登录成功 ===');
        // 同步更新内部 IM 服务状态
        _imService.markLoggedIn(userID);
        return true;
      } else {
        debugPrint(
            '=== TUIKit LoginStore 登录失败: ${result.errorCode}, ${result.errorMessage} ===');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('=== TUIKit LoginStore Login Error: $e ===');
      debugPrint('=== StackTrace: $stackTrace ===');
      return false;
    }
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    // 并行读取存储以加快启动速度
    final results = await Future.wait([
      _storage.read(key: 'jwt_token'),
      _storage.read(key: 'refresh_token'),
      _storage.read(key: 'user_profile_json'),
    ]);

    var token = results[0];
    final refreshToken = results[1];
    final cachedUserJson = results[2];
    debugPrint('=== AppStarted: jwt=${token != null}，启动后将刷新腾讯云 IM UserSig ===');
    if (token == null || token.isEmpty) {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        token = await apiClient.refreshAccessToken();
      }
      if (token == null || token.isEmpty) {
        emit(const AuthUnauthenticated());
        return;
      }
    }

    final cachedUser =
        _userFromJsonString(cachedUserJson) ?? _userFromJwtToken(token);
    if (cachedUser == null) {
      await _clearAuthStorage();
      await _logoutTencentIMAndReset();
      emit(const AuthUnauthenticated());
      return;
    }

    emit(AuthAuthenticated(
      user: cachedUser,
      token: token,
      imToken: null,
      imInitialized: false,
      imConnecting: true,
      isOffline: false,
    ));

    _asyncValidateProfile(token);
    await _clearIMStorage();
    _imLoginAttempts = 0;
    unawaited(_refreshAndLoginIM(cachedUser));
  }

  Future<void> _onConnectivityChanged(
      ConnectivityChanged event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    if (!event.isOnline) {
      if (!currentState.isOffline) {
        emit(currentState.copyWith(isOffline: true));
      }
      return;
    }

    try {
      final response = await apiClient.dio
          .get('/auth/profile')
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final user = User.fromJson(response.data['data']);
        final latestToken =
            await _storage.read(key: 'jwt_token') ?? currentState.token;
        await _cacheUser(user);
        emit(currentState.copyWith(
          user: user,
          token: latestToken,
          isOffline: false,
        ));
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

    if (_isStaleIMToken(currentState.imToken)) {
      await _clearIMStorage();
      _compensateIMToken(currentState.user);
    } else if (currentState.imToken != null && !_imService.isLoggedIn) {
      unawaited(
          _asyncIMLogin(currentState.user.id.toString(), currentState.imToken));
    } else if (currentState.imToken == null) {
      _compensateIMToken(currentState.user);
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
        await _storage.write(
            key: 'last_login_at',
            value: DateTime.now().millisecondsSinceEpoch.toString());
        await _cacheUser(user);
        if (imToken != null) {
          await _storage.write(key: 'im_token', value: imToken);
        }

        final bool imAsync = response.data['data']['imAsync'] ?? false;

        debugPrint(
            '=== Login successful, tencentUserSig=${imToken != null}, imAsync=$imAsync ===');

        emit(AuthAuthenticated(
          user: user,
          token: token,
          imToken: imToken,
          imInitialized: false,
          imConnecting: false,
          isOffline: false,
        ));

        _imLoginGeneration++;
        _imLoginAttempts = 0;
        if (imToken == null && imAsync) {
          _compensateIMToken(user);
        } else if (imToken != null) {
          unawaited(_asyncIMLogin(user.id.toString(), imToken));
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
    await _logoutTencentIMAndReset();
    final error = _pendingLogoutError;
    _pendingLogoutError = null;
    emit(AuthUnauthenticated(error: error));
  }

  // --- 辅助辅助方法 ---

  /// 异步登录 IM（不阻塞 Bloc）
  Future<void> _asyncIMLogin(String userID, String? userSig) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated ||
        currentState.user.id.toString() != userID) {
      debugPrint('=== 腾讯云 IM 登录任务已过期，跳过 ===');
      return;
    }

    if (userSig == null || userSig.isEmpty) {
      _compensateIMToken(currentState.user);
      return;
    }

    final loginKey = '$userID:$userSig';
    if (_activeIMLoginKey == loginKey && _imLoginTask != null) {
      debugPrint('=== 腾讯云 IM 登录已在进行中，跳过重复任务 ===');
      return _imLoginTask;
    }

    final generation = ++_imLoginGeneration;
    _activeIMLoginKey = loginKey;
    _imLoginTask = () async {
      await Future.delayed(const Duration(milliseconds: 500));

      if (generation != _imLoginGeneration) return;

      final success = await _initAndLoginIM(userID, userSig);

      if (generation == _imLoginGeneration && !isClosed) {
        add(IMLoginResult(userID: userID, success: success, userSig: userSig));
      }
    }();

    try {
      await _imLoginTask;
    } finally {
      if (_activeIMLoginKey == loginKey) {
        _activeIMLoginKey = null;
        _imLoginTask = null;
      }
    }
  }

  void _compensateIMToken(User user) {
    if (_imLoginAttempts >= _maxIMLoginAttempts) {
      debugPrint('=== 腾讯云 IM 登录重试已达上限，停止补偿 ===');
      return;
    }

    unawaited(_refreshAndLoginIM(user, delay: const Duration(seconds: 2)));
  }

  Future<void> _onIMLoginResult(
      IMLoginResult event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is AuthAuthenticated &&
        currentState.user.id.toString() == event.userID) {
      emit(currentState.copyWith(
        imInitialized: event.success,
        imConnecting: false,
        imToken: event.userSig,
      ));
      if (event.success) {
        _imLoginAttempts = 0;
        return;
      }

      if (!event.success) {
        _imLoginAttempts++;
        debugPrint('=== 腾讯云 IM 登录失败，清理 IM Token 并尝试重新获取 ===');
        await _clearIMStorage();
        _compensateIMToken(currentState.user);
      }
    }
  }

  Future<void> _refreshAndLoginIM(
    User user, {
    Duration delay = Duration.zero,
  }) async {
    final userID = user.id.toString();
    if (_activeIMRefreshUserID == userID && _imRefreshTask != null) {
      debugPrint('=== 腾讯云 IM UserSig 补偿请求已在进行中，跳过重复任务 ===');
      return _imRefreshTask;
    }

    _activeIMRefreshUserID = userID;
    _imRefreshTask = () async {
      try {
        debugPrint('=== 开始补偿获取腾讯云 IM UserSig ===');
        if (delay > Duration.zero) {
          await Future.delayed(delay);
        }

        final currentState = state;
        if (currentState is! AuthAuthenticated ||
            currentState.user.id.toString() != userID) {
          debugPrint('=== 腾讯云 IM UserSig 补偿任务已过期，跳过 ===');
          return;
        }

        final response = await apiClient.dio
            .get('/auth/im-token')
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final newUserSig = response.data['data']['imToken'];

          if (newUserSig != null) {
            final latestState = state;
            if (latestState is! AuthAuthenticated ||
                latestState.user.id.toString() != userID) {
              debugPrint('=== 腾讯云 IM UserSig 已返回但用户状态已变化，跳过登录 ===');
              return;
            }

            debugPrint('=== 补偿获取腾讯云 IM UserSig 成功 ===');
            await _storage.write(key: 'im_token', value: newUserSig);

            unawaited(_asyncIMLogin(userID, newUserSig));
          }
        }
      } catch (e) {
        debugPrint('=== 补偿获取腾讯云 IM UserSig 失败: $e ===');
      }
    }();

    try {
      await _imRefreshTask;
    } finally {
      if (_activeIMRefreshUserID == userID) {
        _activeIMRefreshUserID = null;
        _imRefreshTask = null;
      }
    }
  }

  Future<void> _onUserUpdated(
      UserUpdated event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      emit(currentState.copyWith(user: event.user, token: event.token));
    }
  }
}
