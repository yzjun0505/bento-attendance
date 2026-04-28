import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginButtonPressed() {
    BlocProvider.of<AuthBloc>(context).add(
      LoggedIn(
        username: _usernameController.text,
        password: _passwordController.text,
      ),
    );
  }

  void _enterGuestMode() {
    // TODO: 触发 AuthGuest 状态
    // context.read<AuthBloc>().add(EnterGuestMode());
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
        child: Stack(
          children: [
            // 背景动效 (Blobs) — 跟随主题
            _buildBackgroundBlobs(colors),
            // 主内容
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: BentoSpacing.space24,
                    vertical: BentoSpacing.space48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(colors, theme),
                      const SizedBox(height: BentoSpacing.space32),
                      // 登录表单
                      _buildLoginForm(colors, theme),
                      const SizedBox(height: BentoSpacing.space20),
                      // 登录按钮
                      _buildLoginButton(colors),
                      const SizedBox(height: BentoSpacing.space16),
                      // 页脚链接
                      _buildFooterLinks(colors),
                      const SizedBox(height: BentoSpacing.space32),
                      // 社交登录
                      _buildSocialLogin(colors, theme),
                      const SizedBox(height: BentoSpacing.space24),
                      // 游客模式入口
                      BentoButton.ghost(
                        text: '游客模式进入',
                        icon: Icons.explore_outlined,
                        size: BentoButtonSize.medium,
                        onPressed: _enterGuestMode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundBlobs(BentoColors colors) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -100 + (20 * _animationController.value),
              right: -50 - (20 * _animationController.value),
              child: _Blob(
                color: colors.primary.withValues(alpha: 0.12),
                size: 300,
              ),
            ),
            Positioned(
              bottom: 100 - (30 * _animationController.value),
              left: -80 + (20 * _animationController.value),
              child: _Blob(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                size: 280,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BentoColors colors, ThemeData theme) {
    return Column(
      children: [
        // Logo
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.95, end: 1.05),
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: colors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on_rounded, size: 40, color: Colors.white),
              ),
            );
          },
        ),
        const SizedBox(height: BentoSpacing.space20),
        Text(
          "Bento Attendance",
          style: theme.textTheme.headlineMedium?.copyWith(
            color: colors.textPrimary,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: BentoSpacing.space8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "极简 · 严谨 · 高效",
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BentoColors colors, ThemeData theme) {
    return BentoCard(
      padding: const EdgeInsets.all(BentoSpacing.space4),
      child: Column(
        children: [
          // 用户名输入框
          BentoInput(
            controller: _usernameController,
            hint: '用户名',
            prefixIcon: const Icon(Icons.person_rounded),
            textInputAction: TextInputAction.next,
          ),
          Divider(height: 1, color: colors.divider),
          // 密码输入框
          BentoInput(
            controller: _passwordController,
            hint: '密码',
            prefixIcon: const Icon(Icons.lock_rounded),
            obscureText: _obscurePassword,
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
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

  Widget _buildLoginButton(BentoColors colors) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return BentoButton.primary(
          text: '登录系统',
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
          onPressed: () {},
          child: Text(
            "忘记密码",
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
          onPressed: () {},
          child: Text(
            "新用户注册",
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

  Widget _buildSocialLogin(BentoColors colors, ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: colors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "其他登录方式",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
            Expanded(child: Divider(color: colors.divider)),
          ],
        ),
        const SizedBox(height: BentoSpacing.space16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialIcon(icon: Icons.apple_rounded, colors: colors),
            const SizedBox(width: 20),
            _SocialIcon(icon: Icons.fingerprint_rounded, colors: colors),
            const SizedBox(width: 20),
            _SocialIcon(icon: Icons.face_unlock_rounded, colors: colors),
          ],
        ),
      ],
    );
  }

  void _showErrorDialog(BuildContext context, String message, BentoColors colors) {
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
              style: TextButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                '确定',
                style: TextStyle(
                  color: colors.textOnPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final BentoColors colors;

  const _SocialIcon({required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(BentoRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Icon(icon, color: colors.textSecondary, size: 24),
    );
  }
}
