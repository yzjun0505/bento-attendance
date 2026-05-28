import 'package:flutter/material.dart';
import '../core/bento_colors.dart';
import '../core/bento_typography.dart';

/// BentoLoading — 加载态组件
///
/// 变体：
/// - BentoLoading.spinner()   → 居中旋转指示器
/// - BentoLoading.overlay()   → 全屏半透明遮罩 + 指示器
/// - BentoLoading.inline()    → 小型行内指示器
class BentoLoading extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  // ignore: unused_element
  const BentoLoading._({
    // ignore: unused_element_parameter
    super.key,
    // ignore: unused_element_parameter
    this.size = 36,
    // ignore: unused_element_parameter
    this.strokeWidth = 3,
    // ignore: unused_element_parameter
    this.color,
  });

  /// 居中旋转指示器
  const BentoLoading.spinner({
    super.key,
    this.size = 36,
    this.strokeWidth = 3,
    this.color,
  });

  /// 小型行内指示器
  const BentoLoading.inline({
    super.key,
    this.size = 18,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: color ?? colors.primary,
        ),
      ),
    );
  }
}

/// BentoLoadingOverlay — 全屏半透明遮罩
class BentoLoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;
  final String? message;

  const BentoLoadingOverlay({
    super.key,
    required this.loading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      children: [
        child,
        if (loading)
          Positioned.fill(
            child: Container(
              color: colors.background.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BentoLoading.spinner(color: colors.primary),
                    if (message != null) ...[
                      const SizedBox(height: BentoSpacing.space16),
                      Text(
                        message!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
