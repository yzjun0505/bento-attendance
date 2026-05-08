import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../core/bento_colors.dart';
import '../core/bento_typography.dart';
import 'bento_widgets.dart';

/// LoginPromptSheet — 访客点击需要登录的操作时弹出
///
/// 使用方式：
/// ```dart
/// final result = await showLoginPromptSheet(context);
/// if (result == true) { ... }
/// ```
Future<bool?> showLoginPromptSheet(BuildContext context) {
  return BentoBottomSheet.show<bool>(
    context: context,
    heightFactor: 0.4,
    child: const _LoginPromptContent(),
  );
}

class _LoginPromptContent extends StatelessWidget {
  const _LoginPromptContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(BentoSpacing.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 锁图标
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, size: 28, color: colors.primary),
          ),
          const SizedBox(height: BentoSpacing.space20),
          // 标题
          Text(
            '登录后即可使用此功能',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BentoSpacing.space8),
          // 描述
          Text(
            '打卡、查看记录等操作需要登录账号',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: BentoSpacing.space24),
          // 登录按钮
          BentoButton.primary(
            text: '立即登录',
            size: BentoButtonSize.large,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          const SizedBox(height: BentoSpacing.space8),
          // 取消按钮
          BentoButton.ghost(
            text: '稍后再说',
            size: BentoButtonSize.medium,
            fullWidth: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// 权限守卫 — 在需要登录的操作前检查
///
/// 使用方式：
/// ```dart
/// final authorized = await requireAuth(context);
/// if (authorized) { ... }
/// ```
Future<bool> requireAuth(BuildContext context) async {
  final authState = context.read<AuthBloc>().state;
  if (authState is AuthAuthenticated) return true;
  final wantsLogin = await showLoginPromptSheet(context) ?? false;
  if (wantsLogin && context.mounted) {
    context.read<AuthBloc>().add(LoggedOut());
  }
  return false;
}
