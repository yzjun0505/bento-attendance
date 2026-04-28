import 'package:flutter/material.dart';
import '../core/bento_colors.dart';
import '../core/bento_typography.dart';

/// BentoButton — 统一按钮体系
///
/// 类型：
/// - BentoButton.primary()   → 蓝色渐变背景 + 白色文字
/// - BentoButton.secondary() → surface 背景 + primary 边框
/// - BentoButton.ghost()     → 透明背景 + primary 文字
/// - BentoButton.danger()    → 红色背景 + 白色文字
/// - BentoButton.success()   → 绿色背景 + 白色文字
///
/// 尺寸：
/// - BentoButtonSize.large   → height: 56, fontSize: 18
/// - BentoButtonSize.medium  → height: 48, fontSize: 16
/// - BentoButtonSize.small   → height: 40, fontSize: 14
class BentoButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final BentoButtonType type;
  final BentoButtonSize size;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;

  // ignore: unused_element
  const BentoButton._({
    // ignore: unused_element_parameter
    super.key,
    required this.text,
    // ignore: unused_element_parameter
    this.onPressed,
    required this.type,
    // ignore: unused_element_parameter
    this.size = BentoButtonSize.medium,
    // ignore: unused_element_parameter
    this.loading = false,
    // ignore: unused_element_parameter
    this.icon,
    // ignore: unused_element_parameter
    this.fullWidth = false,
  });

  /// 主要按钮 — 蓝色渐变
  const BentoButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = BentoButtonSize.medium,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
  }) : type = BentoButtonType.primary;

  /// 次要按钮 — surface + primary 边框
  const BentoButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = BentoButtonSize.medium,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
  }) : type = BentoButtonType.secondary;

  /// 幽灵按钮 — 透明 + primary 文字
  const BentoButton.ghost({
    super.key,
    required this.text,
    this.onPressed,
    this.size = BentoButtonSize.medium,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
  }) : type = BentoButtonType.ghost;

  /// 危险按钮 — 红色背景
  const BentoButton.danger({
    super.key,
    required this.text,
    this.onPressed,
    this.size = BentoButtonSize.medium,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
  }) : type = BentoButtonType.danger;

  /// 成功按钮 — 绿色背景
  const BentoButton.success({
    super.key,
    required this.text,
    this.onPressed,
    this.size = BentoButtonSize.medium,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
  }) : type = BentoButtonType.success;

  @override
  State<BentoButton> createState() => _BentoButtonState();
}

class _BentoButtonState extends State<BentoButton> {
  bool _pressed = false;

  double get _height {
    switch (widget.size) {
      case BentoButtonSize.large:
        return 56;
      case BentoButtonSize.medium:
        return 48;
      case BentoButtonSize.small:
        return 40;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case BentoButtonSize.large:
        return 18;
      case BentoButtonSize.medium:
        return 16;
      case BentoButtonSize.small:
        return 14;
    }
  }

  double get _borderRadius {
    switch (widget.size) {
      case BentoButtonSize.large:
        return BentoRadius.md;
      case BentoButtonSize.medium:
        return BentoRadius.sm;
      case BentoButtonSize.small:
        return BentoRadius.sm;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case BentoButtonSize.large:
        return 22;
      case BentoButtonSize.medium:
        return 20;
      case BentoButtonSize.small:
        return 18;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDisabled = widget.onPressed == null || widget.loading;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: isDisabled ? null : (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: isDisabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: isDisabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: _height,
            width: widget.fullWidth ? double.infinity : null,
            decoration: _buildDecoration(colors),
            child: _buildContent(colors),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(BentoColors colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (widget.type) {
      case BentoButtonType.primary:
        return BoxDecoration(
          gradient: colors.primaryGradient,
          borderRadius: BorderRadius.circular(_borderRadius),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        );
      case BentoButtonType.secondary:
        return BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(_borderRadius),
          border: Border.all(color: colors.primary, width: 1.5),
        );
      case BentoButtonType.ghost:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(_borderRadius),
        );
      case BentoButtonType.danger:
        return BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(_borderRadius),
        );
      case BentoButtonType.success:
        return BoxDecoration(
          color: colors.success,
          borderRadius: BorderRadius.circular(_borderRadius),
        );
    }
  }

  Widget _buildContent(BentoColors colors) {
    final textColor = _getTextColor(colors);
    final children = <Widget>[];

    if (widget.loading) {
      children.add(SizedBox(
        width: _iconSize,
        height: _iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: textColor,
        ),
      ));
      children.add(const SizedBox(width: 8));
    } else if (widget.icon != null) {
      children.add(Icon(widget.icon, size: _iconSize, color: textColor));
      children.add(const SizedBox(width: 8));
    }

    children.add(Text(
      widget.text,
      style: TextStyle(
        fontSize: _fontSize,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1,
      ),
    ));

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Color _getTextColor(BentoColors colors) {
    switch (widget.type) {
      case BentoButtonType.primary:
        return colors.textOnPrimary;
      case BentoButtonType.secondary:
        return colors.primary;
      case BentoButtonType.ghost:
        return colors.primary;
      case BentoButtonType.danger:
        return colors.textOnPrimary;
      case BentoButtonType.success:
        return colors.textOnPrimary;
    }
  }
}

enum BentoButtonType { primary, secondary, ghost, danger, success }

enum BentoButtonSize { large, medium, small }
