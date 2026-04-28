import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/bento_colors.dart';
import '../core/bento_typography.dart';

/// BentoCard — 统一卡片组件
/// 替代旧 BentoCard（从 theme.dart 移出），支持多种变体
///
/// 变体：
/// - BentoCard()         → elevated（暗色：毛玻璃+边框，亮色：阴影）
/// - BentoCard.outlined() → 仅边框无阴影
/// - BentoCard.filled()   → 填充色无边框
/// - BentoCard.interactive() → 可点击，hover/press 态
class BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? customBgColor;
  final Color? customBorderColor;
  final List<BoxShadow>? customShadow;
  final VoidCallback? onTap;
  final bool useGlassMorphism;

  /// 卡片变体
  final _BentoCardVariant _variant;

  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BentoSpacing.space20),
    this.margin,
    this.borderRadius = BentoRadius.md,
    this.customBgColor,
    this.customBorderColor,
    this.customShadow,
    this.onTap,
    this.useGlassMorphism = true,
  }) : _variant = _BentoCardVariant.elevated;

  const BentoCard.outlined({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BentoSpacing.space20),
    this.margin,
    this.borderRadius = BentoRadius.md,
    this.customBorderColor,
    this.onTap,
  })  : customBgColor = null,
        customShadow = null,
        useGlassMorphism = false,
        _variant = _BentoCardVariant.outlined;

  const BentoCard.filled({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BentoSpacing.space20),
    this.margin,
    this.borderRadius = BentoRadius.md,
    this.customBgColor,
    this.onTap,
  })  : customBorderColor = null,
        customShadow = null,
        useGlassMorphism = false,
        _variant = _BentoCardVariant.filled;

  const BentoCard.interactive({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BentoSpacing.space20),
    this.margin,
    this.borderRadius = BentoRadius.md,
    this.onTap,
  })  : customBgColor = null,
        customBorderColor = null,
        customShadow = null,
        useGlassMorphism = false,
        _variant = _BentoCardVariant.interactive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = customBgColor ?? _getBgColor(colors, isDark);
    final borderColor = customBorderColor ?? _getBorderColor(colors);
    final shadow = customShadow ?? _getShadow(colors, isDark);
    final shouldUseGlass = useGlassMorphism && isDark && _variant == _BentoCardVariant.elevated;

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: shouldUseGlass ? null : bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: shouldUseGlass
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    color: bgColor,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                    ),
                  ),
                  child: child,
                ),
              )
            : Padding(padding: padding, child: child),
      ),
    );

    if (_variant == _BentoCardVariant.interactive && onTap != null) {
      return _InteractiveWrapper(
        onTap: onTap!,
        borderRadius: borderRadius,
        child: card,
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }

  Color _getBgColor(BentoColors colors, bool isDark) {
    switch (_variant) {
      case _BentoCardVariant.elevated:
        return colors.surface;
      case _BentoCardVariant.outlined:
        return Colors.transparent;
      case _BentoCardVariant.filled:
        return colors.surfaceVariant;
      case _BentoCardVariant.interactive:
        return colors.surface;
    }
  }

  Color _getBorderColor(BentoColors colors) {
    switch (_variant) {
      case _BentoCardVariant.elevated:
      case _BentoCardVariant.outlined:
        return colors.border;
      case _BentoCardVariant.filled:
        return Colors.transparent;
      case _BentoCardVariant.interactive:
        return colors.border;
    }
  }

  List<BoxShadow>? _getShadow(BentoColors colors, bool isDark) {
    if (isDark) return null; // 暗色不用阴影
    switch (_variant) {
      case _BentoCardVariant.elevated:
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ];
      case _BentoCardVariant.outlined:
      case _BentoCardVariant.filled:
        return null;
      case _BentoCardVariant.interactive:
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
    }
  }
}

enum _BentoCardVariant { elevated, outlined, filled, interactive }

/// 可交互包装 — 点击缩放反馈
class _InteractiveWrapper extends StatefulWidget {
  final VoidCallback onTap;
  final double borderRadius;
  final Widget child;

  const _InteractiveWrapper({
    required this.onTap,
    required this.borderRadius,
    required this.child,
  });

  @override
  State<_InteractiveWrapper> createState() => _InteractiveWrapperState();
}

class _InteractiveWrapperState extends State<_InteractiveWrapper> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
