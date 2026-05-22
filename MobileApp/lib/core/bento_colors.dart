import 'package:flutter/material.dart';

/// Bento 语义化颜色令牌
/// 通过 ThemeExtension 注入，替代旧的 BentoTheme 静态方法
/// 使用方式：Theme.of(context).extension<BentoColors>()!.background
class BentoColors extends ThemeExtension<BentoColors> {
  // --- 背景 ---
  final Color background; // 页面底色
  final Color surface; // 卡片/容器底色
  final Color surfaceVariant; // 次级表面（输入框底色等）

  // --- 文字 ---
  final Color textPrimary; // 主文字（标题/正文）
  final Color textSecondary; // 辅助文字（描述/时间）
  final Color textTertiary; // 弱化文字（提示/占位）
  final Color textOnPrimary; // 主色上的文字（白色）

  // --- 语义色 ---
  final Color primary; // 主色（蓝）
  final Color primaryLight; // 主色浅底（用于 Badge 背景）
  final Color primaryVariant; // 主色变体
  final Color secondary; // 次要色（紫）
  final Color secondaryLight; // 次要色浅底
  final Color success; // 成功（绿）
  final Color successLight; // 成功浅底
  final Color warning; // 警告（橙）
  final Color warningLight; // 警告浅底
  final Color error; // 错误（红）
  final Color errorLight; // 错误浅底
  final Color info; // 信息（青）
  final Color shadow; // 阴影色

  // --- 边框/分割 ---
  final Color border; // 卡片/输入框边框
  final Color divider; // 列表分割线

  // --- 导航栏 ---
  final Color navBarBg; // 底部导航栏背景
  final Color navBarBorder; // 底部导航栏上边框

  // --- 渐变 ---
  final LinearGradient primaryGradient;

  const BentoColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnPrimary,
    required this.primary,
    required this.primaryLight,
    required this.primaryVariant,
    required this.secondary,
    required this.secondaryLight,
    required this.success,
    required this.successLight,
    required this.warning,
    required this.warningLight,
    required this.error,
    required this.errorLight,
    required this.info,
    required this.shadow,
    required this.border,
    required this.divider,
    required this.navBarBg,
    required this.navBarBorder,
    required this.primaryGradient,
  });

  /// 暗色主题
  static const dark = BentoColors(
    background: Color(0xFF0A0B11),
    surface: Color(0xFF161823),
    surfaceVariant: Color(0xFF1E2030),
    textPrimary: Color(0xFFF1F3F5),
    textSecondary: Color(0xFF8B92A5),
    textTertiary: Color(0xFF4A5568),
    textOnPrimary: Color(0xFFFFFFFF),
    primary: Color(0xFF3B82F6),
    primaryLight: Color(0xFF1E3A5F),
    primaryVariant: Color(0xFF1D4ED8),
    secondary: Color(0xFF8B5CF6),
    secondaryLight: Color(0xFF2E1F5C),
    success: Color(0xFF10B981),
    successLight: Color(0xFF0D3B2E),
    warning: Color(0xFFF59E0B),
    warningLight: Color(0xFF3B2E0D),
    error: Color(0xFFEF4444),
    errorLight: Color(0xFF3B1010),
    info: Color(0xFF06B6D4),
    shadow: Color(0xFF000000),
    border: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
    divider: Color(0x0DFFFFFF), // rgba(255,255,255,0.05)
    navBarBg: Color(0xFF0F1018),
    navBarBorder: Color(0x14FFFFFF),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// 亮色主题
  static const light = BentoColors(
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF0F2F5),
    textPrimary: Color(0xFF1A1D26),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    textOnPrimary: Color(0xFFFFFFFF),
    primary: Color(0xFF3B82F6),
    primaryLight: Color(0xFFEBF2FF),
    primaryVariant: Color(0xFF1D4ED8),
    secondary: Color(0xFF8B5CF6),
    secondaryLight: Color(0xFFF3E8FF),
    success: Color(0xFF10B981),
    successLight: Color(0xFFECFDF5),
    warning: Color(0xFFF59E0B),
    warningLight: Color(0xFFFFFBEB),
    error: Color(0xFFEF4444),
    errorLight: Color(0xFFFEF2F2),
    info: Color(0xFF06B6D4),
    shadow: Color(0xFF000000),
    border: Color(0x14000000), // rgba(0,0,0,0.08)
    divider: Color(0x0D000000), // rgba(0,0,0,0.05)
    navBarBg: Color(0xFFFFFFFF),
    navBarBorder: Color(0x14000000),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  @override
  BentoColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnPrimary,
    Color? primary,
    Color? primaryLight,
    Color? primaryVariant,
    Color? secondary,
    Color? secondaryLight,
    Color? success,
    Color? successLight,
    Color? warning,
    Color? warningLight,
    Color? error,
    Color? errorLight,
    Color? info,
    Color? shadow,
    Color? border,
    Color? divider,
    Color? navBarBg,
    Color? navBarBorder,
    LinearGradient? primaryGradient,
  }) {
    return BentoColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryVariant: primaryVariant ?? this.primaryVariant,
      secondary: secondary ?? this.secondary,
      secondaryLight: secondaryLight ?? this.secondaryLight,
      success: success ?? this.success,
      successLight: successLight ?? this.successLight,
      warning: warning ?? this.warning,
      warningLight: warningLight ?? this.warningLight,
      error: error ?? this.error,
      errorLight: errorLight ?? this.errorLight,
      info: info ?? this.info,
      shadow: shadow ?? this.shadow,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      navBarBg: navBarBg ?? this.navBarBg,
      navBarBorder: navBarBorder ?? this.navBarBorder,
      primaryGradient: primaryGradient ?? this.primaryGradient,
    );
  }

  @override
  BentoColors lerp(BentoColors? other, double t) {
    if (other is! BentoColors) return this;
    return BentoColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryVariant: Color.lerp(primaryVariant, other.primaryVariant, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryLight: Color.lerp(secondaryLight, other.secondaryLight, t)!,
      success: Color.lerp(success, other.success, t)!,
      successLight: Color.lerp(successLight, other.successLight, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningLight: Color.lerp(warningLight, other.warningLight, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorLight: Color.lerp(errorLight, other.errorLight, t)!,
      info: Color.lerp(info, other.info, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      navBarBg: Color.lerp(navBarBg, other.navBarBg, t)!,
      navBarBorder: Color.lerp(navBarBorder, other.navBarBorder, t)!,
      primaryGradient:
          LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
    );
  }
}

/// 便捷扩展方法 — 用 context.colors.xxx 替代 Theme.of(context).extension<BentoColors>()!.xxx
extension BentoColorsX on BuildContext {
  BentoColors get colors => Theme.of(this).extension<BentoColors>()!;
}
