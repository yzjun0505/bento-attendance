import 'package:flutter/material.dart';
import '../core/bento_colors.dart';


/// BentoBadge — 状态标签/角标
///
/// 类型：
/// - BentoBadge.primary()   → 蓝色浅底 + 蓝色文字
/// - BentoBadge.success()   → 绿色浅底 + 绿色文字
/// - BentoBadge.warning()   → 橙色浅底 + 橙色文字
/// - BentoBadge.error()     → 红色浅底 + 红色文字
/// - BentoBadge.neutral()   → 灰色浅底 + 灰色文字
class BentoBadge extends StatelessWidget {
  final String text;
  final BentoBadgeType type;
  final IconData? icon;
  final double fontSize;

  // ignore: unused_element
  const BentoBadge._({
    // ignore: unused_element_parameter
    super.key,
    required this.text,
    required this.type,
    // ignore: unused_element_parameter
    this.icon,
    // ignore: unused_element_parameter
    this.fontSize = 10,
  });

  const BentoBadge.primary({
    super.key,
    required this.text,
    this.icon,
    this.fontSize = 10,
  }) : type = BentoBadgeType.primary;

  const BentoBadge.success({
    super.key,
    required this.text,
    this.icon,
    this.fontSize = 10,
  }) : type = BentoBadgeType.success;

  const BentoBadge.warning({
    super.key,
    required this.text,
    this.icon,
    this.fontSize = 10,
  }) : type = BentoBadgeType.warning;

  const BentoBadge.error({
    super.key,
    required this.text,
    this.icon,
    this.fontSize = 10,
  }) : type = BentoBadgeType.error;

  const BentoBadge.neutral({
    super.key,
    required this.text,
    this.icon,
    this.fontSize = 10,
  }) : type = BentoBadgeType.neutral;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bgColor = _getBgColor(colors);
    final textColor = _getTextColor(colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 14 / fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBgColor(BentoColors colors) {
    switch (type) {
      case BentoBadgeType.primary:
        return colors.primaryLight;
      case BentoBadgeType.success:
        return colors.successLight;
      case BentoBadgeType.warning:
        return colors.warningLight;
      case BentoBadgeType.error:
        return colors.errorLight;
      case BentoBadgeType.neutral:
        return colors.surfaceVariant;
    }
  }

  Color _getTextColor(BentoColors colors) {
    switch (type) {
      case BentoBadgeType.primary:
        return colors.primary;
      case BentoBadgeType.success:
        return colors.success;
      case BentoBadgeType.warning:
        return colors.warning;
      case BentoBadgeType.error:
        return colors.error;
      case BentoBadgeType.neutral:
        return colors.textSecondary;
    }
  }
}

enum BentoBadgeType { primary, success, warning, error, neutral }
