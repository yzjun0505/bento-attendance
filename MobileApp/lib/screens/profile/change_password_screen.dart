import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../api/dio_client.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../core/bento_colors.dart';
import '../../core/bento_typography.dart';
import '../../widgets/bento_card.dart';
import '../../widgets/bento_button.dart';
import '../../repositories/user_repository.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _userRepository = UserRepository(apiClient: ApiClient());
  bool _isLoading = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _userRepository.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    final colors = context.colors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BentoRadius.md),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: colors.success, size: 28),
              const SizedBox(width: 12),
              Text(
                '修改成功',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            '密码已成功修改，请重新登录',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<AuthBloc>().add(LoggedOut());
              },
              style: TextButton.styleFrom(
                backgroundColor: colors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                '重新登录',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BentoRadius.md),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: colors.error, size: 28),
              const SizedBox(width: 12),
              Text(
                '修改失败',
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
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BentoRadius.sm),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                '确定',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: colors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '修改密码',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _buildIconHeader(colors),
                const SizedBox(height: 40),
                BentoCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildPasswordField(
                        controller: _oldPasswordController,
                        hintText: "旧密码",
                        icon: Icons.lock_outline,
                        obscureText: _obscureOldPassword,
                        onToggleVisibility: () {
                          setState(
                              () => _obscureOldPassword = !_obscureOldPassword);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入旧密码';
                          }
                          return null;
                        },
                        colors: colors,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          color: colors.divider,
                          height: 1,
                        ),
                      ),
                      _buildPasswordField(
                        controller: _newPasswordController,
                        hintText: "新密码",
                        icon: Icons.lock_rounded,
                        obscureText: _obscureNewPassword,
                        onToggleVisibility: () {
                          setState(
                              () => _obscureNewPassword = !_obscureNewPassword);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入新密码';
                          }
                          if (value.length < 6) {
                            return '新密码至少6位';
                          }
                          return null;
                        },
                        colors: colors,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          color: colors.divider,
                          height: 1,
                        ),
                      ),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        hintText: "确认新密码",
                        icon: Icons.lock_rounded,
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () {
                          setState(() => _obscureConfirmPassword =
                              !_obscureConfirmPassword);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请确认新密码';
                          }
                          if (value != _newPasswordController.text) {
                            return '两次密码不一致';
                          }
                          return null;
                        },
                        colors: colors,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                BentoButton.primary(
                  text: '确认修改',
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _handleSubmit,
                  size: BentoButtonSize.large,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconHeader(BentoColors colors) {
    return Center(
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
        child:
            Icon(Icons.security_rounded, size: 40, color: colors.textOnPrimary),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
    required BentoColors colors,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: colors.textSecondary.withValues(alpha: 0.6),
          fontSize: 15,
        ),
        prefixIcon: Icon(
          icon,
          color: colors.textSecondary.withValues(alpha: 0.8),
          size: 22,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: colors.textSecondary.withValues(alpha: 0.6),
            size: 22,
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BentoRadius.md),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        errorStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
