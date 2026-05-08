import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/dio_client.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController();
  bool _obscurePassword = true;
  bool _testingServer = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = ApiClient.baseUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  void _onLoginButtonPressed() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      _showMessage('请输入用户名和密码');
      return;
    }

    context.read<AuthBloc>().add(
          LoggedIn(username: username, password: password),
        );
  }

  Future<void> _openRegister() async {
    final username = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (username != null && username.isNotEmpty && mounted) {
      _usernameController.text = username;
      _showMessage('注册成功，请输入密码登录');
    }
  }

  Future<void> _saveServerAddress(String value) async {
    final normalized = ApiClient.normalizeApiBaseUrl(value);
    await ApiClient.saveRuntimeApiBaseUrl(normalized);
    if (!mounted) return;
    context.read<AuthBloc>().apiClient.reloadOptions();
    _serverController.text = normalized;
  }

  Future<void> _testServer(String value) async {
    setState(() => _testingServer = true);
    final normalized = ApiClient.normalizeApiBaseUrl(value);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final resp = await dio.get('/health');
      final ok = resp.statusCode == 200 &&
          (resp.data['code'] == 200 || resp.data['message'] == 'OK');
      if (!mounted) return;
      _showMessage(ok ? '后端连接正常' : '后端可访问，但依赖状态异常');
    } catch (_) {
      if (!mounted) return;
      _showMessage('连接失败，请确认电脑和手机在同一网络，且后端已启动');
    } finally {
      if (mounted) setState(() => _testingServer = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated && state.error != null) {
            _showErrorDialog(context, state.error!, colors);
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: BentoSpacing.space24,
                vertical: BentoSpacing.space32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(colors, theme),
                    const SizedBox(height: BentoSpacing.space24),
                    _buildLoginForm(colors, theme),
                    const SizedBox(height: BentoSpacing.space16),
                    _buildServerCard(colors, theme),
                    const SizedBox(height: BentoSpacing.space20),
                    _buildLoginButton(colors),
                    const SizedBox(height: BentoSpacing.space12),
                    _buildFooterLinks(colors),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BentoColors colors, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: colors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.location_on_rounded,
              size: 34, color: Colors.white),
        ),
        const SizedBox(height: BentoSpacing.space20),
        Text(
          '境图考勤',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        Text(
          '定位打卡、现场记录与团队协同',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BentoColors colors, ThemeData theme) {
    return BentoCard(
      padding: const EdgeInsets.all(BentoSpacing.space4),
      borderRadius: BentoRadius.lg,
      child: Column(
        children: [
          BentoInput(
            controller: _usernameController,
            hint: '用户名',
            prefixIcon: const Icon(Icons.person_rounded),
            textInputAction: TextInputAction.next,
          ),
          Divider(height: 1, color: colors.divider),
          BentoInput(
            controller: _passwordController,
            hint: '密码',
            prefixIcon: const Icon(Icons.lock_rounded),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: colors.textTertiary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard(BentoColors colors, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BentoRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.dns_outlined, color: colors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '后端服务地址',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ApiClient.baseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showServerSettings,
            child: const Text('修改'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BentoColors colors) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return BentoButton.primary(
          text: '登录',
          size: BentoButtonSize.large,
          fullWidth: true,
          loading: isLoading,
          icon: Icons.arrow_forward_rounded,
          onPressed: isLoading ? null : _onLoginButtonPressed,
        );
      },
    );
  }

  Widget _buildFooterLinks(BentoColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _showForgotPasswordDialog,
          child: Text(
            '忘记密码',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
        ),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: colors.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        TextButton(
          onPressed: _openRegister,
          child: Text(
            '新用户注册',
            style: TextStyle(
              color: colors.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _showForgotPasswordDialog() {
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('忘记密码', style: TextStyle(color: colors.textPrimary)),
          content: Text(
            '当前系统没有短信或邮箱找回密码功能。请联系管理员在管理后台「人员管理」中为你重置密码。',
            style: TextStyle(color: colors.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showServerSettings() async {
    final colors = context.colors;
    _serverController.text = ApiClient.baseUrl;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: BentoSpacing.space20,
                right: BentoSpacing.space20,
                top: BentoSpacing.space20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                    BentoSpacing.space20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '配置后端服务',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '真机调试时填电脑局域网 IP，例如 http://192.168.1.10:3000/api',
                    style: TextStyle(
                        color: colors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: BentoSpacing.space16),
                  TextField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.link),
                      hintText: 'http://192.168.1.10:3000/api',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(BentoRadius.sm)),
                    ),
                  ),
                  const SizedBox(height: BentoSpacing.space16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testingServer
                              ? null
                              : () async {
                                  setSheetState(() => _testingServer = true);
                                  await _testServer(_serverController.text);
                                  if (mounted) {
                                    setSheetState(() => _testingServer = false);
                                  }
                                },
                          icon: _testingServer
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check),
                          label: const Text('测试'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _saveServerAddress(_serverController.text);
                            if (mounted && sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                              _showMessage('服务地址已保存');
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showErrorDialog(
      BuildContext context, String message, BentoColors colors) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BentoRadius.lg),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: colors.error, size: 28),
              const SizedBox(width: 12),
              Text(
                '登录失败',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
