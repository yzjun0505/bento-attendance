import 'package:flutter/material.dart';
import '../core/bento_colors.dart';

/// BentoAvatar — 头像组件
///
/// 支持：网络图片、本地资源、文字占位、图标占位
class BentoAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final String? text;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const BentoAvatar({
    super.key,
    this.size = 44,
    this.imageUrl,
    this.text,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  /// 大头像（个人中心用）
  const BentoAvatar.large({
    super.key,
    this.imageUrl,
    this.text,
    this.icon,
    this.backgroundColor,
    this.textColor,
  }) : size = 72;

  /// 小头像（列表项用）
  const BentoAvatar.small({
    super.key,
    this.imageUrl,
    this.text,
    this.icon,
    this.backgroundColor,
    this.textColor,
  }) : size = 32;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = backgroundColor ?? colors.surfaceVariant;
    final fg = textColor ?? colors.textSecondary;

    Widget child;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(bg, fg),
        ),
      );
      return child;
    } else {
      child = _buildPlaceholder(bg, fg);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }

  Widget _buildPlaceholder(Color bg, Color fg) {
    if (text != null && text!.isNotEmpty) {
      return Center(
        child: Text(
          text![0].toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      );
    }
    if (icon != null) {
      return Center(
        child: Icon(icon, size: size * 0.45, color: fg),
      );
    }
    return Center(
      child: Icon(Icons.person, size: size * 0.45, color: fg),
    );
  }
}
