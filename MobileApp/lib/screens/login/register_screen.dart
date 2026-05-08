import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('请输入用户名和密码');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(username)) {
      _showMessage('用户名只能包含英文字母和数字');
      return;
    }
    if (password.length < 6) {
      _showMessage('密码至少 6 位');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('两次输入的密码不一致');
      return;
    }

    setState(() => _submitting = true);
    try {
      await context
          .read<AuthBloc>()
          .apiClient
          .dio
          .post('/auth/register', data: {
        'username': username,
        'password': password,
        'name': name,
        'phone': phone,
        'role': 'worker',
      });
      if (!mounted) return;
      Navigator.pop(context, username);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? '注册失败，请稍后重试';
      if (mounted) _showMessage(message.toString());
    } catch (e) {
      if (mounted) _showMessage('注册失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('新用户注册')),
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(BentoSpacing.space24),
          children: [
            Text(
              '创建考勤账号',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '注册后默认是普通员工账号，项目和权限由管理员在后台分配。',
              style: TextStyle(color: colors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: BentoSpacing.space24),
            BentoCard(
              padding: const EdgeInsets.all(BentoSpacing.space4),
              borderRadius: BentoRadius.lg,
              child: Column(
                children: [
                  BentoInput(
                    controller: _usernameController,
                    hint: '用户名（英文字母或数字）',
                    prefixIcon: const Icon(Icons.person_rounded),
                    textInputAction: TextInputAction.next,
                  ),
                  Divider(height: 1, color: colors.divider),
                  BentoInput(
                    controller: _nameController,
                    hint: '姓名',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    textInputAction: TextInputAction.next,
                  ),
                  Divider(height: 1, color: colors.divider),
                  BentoInput(
                    controller: _phoneController,
                    hint: '手机号（可选）',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  Divider(height: 1, color: colors.divider),
                  BentoInput(
                    controller: _passwordController,
                    hint: '密码（至少 6 位）',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: colors.textTertiary,
                        size: 20,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: colors.divider),
                  BentoInput(
                    controller: _confirmPasswordController,
                    hint: '确认密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
            const SizedBox(height: BentoSpacing.space20),
            BentoButton.primary(
              text: '注册',
              fullWidth: true,
              size: BentoButtonSize.large,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
