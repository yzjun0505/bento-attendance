import 'package:flutter/material.dart';
import '../core/bento_colors.dart';
import '../core/bento_typography.dart';

/// BentoBottomSheet — 统一底部弹窗
///
/// 特点：
/// - 顶部拖拽条
/// - 圆角 24
/// - 自动跟随主题
///
/// 使用方式：
/// - bentoShowBottomSheet(context, builder: (_) => ...)
/// - BentoBottomSheet.show(context, title: '标题', child: ...)
class BentoBottomSheet {
  /// 显示底部弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    double? heightFactor,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => _BentoBottomSheetContent(
        title: title,
        heightFactor: heightFactor,
        child: child,
      ),
    );
  }
}

class _BentoBottomSheetContent extends StatelessWidget {
  final String? title;
  final double? heightFactor;
  final Widget child;

  const _BentoBottomSheetContent({
    this.title,
    this.heightFactor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: heightFactor != null
          ? BoxConstraints(maxHeight: mediaQuery.size.height * heightFactor!)
          : null,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(BentoRadius.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BentoSpacing.space20,
                BentoSpacing.space8,
                BentoSpacing.space20,
                BentoSpacing.space4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close,
                      size: 22,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          // 内容
          Flexible(child: child),
          // 底部安全区
          SizedBox(height: mediaQuery.padding.bottom),
        ],
      ),
    );
  }
}

/// 便捷函数 — 显示底部弹窗
Future<T?> bentoShowBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  double? heightFactor,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return BentoBottomSheet.show<T>(
    context: context,
    title: title,
    heightFactor: heightFactor,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    child: builder(context),
  );
}
