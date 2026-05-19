import 'package:flutter/material.dart';
import '../core/bento_colors.dart';

/// OfflineBanner — 离线状态提示条
///
/// 贴在顶栏下方，网络恢复后自动消失
/// 使用方式：在页面 Column 中条件渲染
///
/// ```dart
/// if (isOffline)
///   const OfflineBanner()
/// ```
class OfflineBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: topInset + 32,
      decoration: BoxDecoration(
        color: colors.warningLight,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 14, color: colors.warning),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '网络不可用 · 当前为离线模式',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onRetry,
                  child: Text(
                    '重试',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
