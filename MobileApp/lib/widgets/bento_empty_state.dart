import 'package:flutter/material.dart';
import '../core/bento_colors.dart';
import '../core/bento_typography.dart';
import 'bento_button.dart';

/// BentoEmptyState — 空状态占位组件
///
/// 包含：图标 + 标题 + 描述 + 可选操作按钮
class BentoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionText;
  final VoidCallback? onAction;

  const BentoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BentoSpacing.space32,
          vertical: BentoSpacing.space48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: colors.textTertiary,
            ),
            const SizedBox(height: BentoSpacing.space16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: BentoSpacing.space8),
              Text(
                description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: BentoSpacing.space24),
              BentoButton.primary(
                text: actionText!,
                onPressed: onAction,
                size: BentoButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
