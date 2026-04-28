import 'package:flutter/material.dart';
import 'bento_colors.dart';

/// Bento 排版令牌
/// 统一字体层级，替代各页面硬编码的 TextStyle
class BentoTypography {
  // --- 暗色排版 ---
  static TextTheme darkTextTheme() => const TextTheme(
    displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 36 / 28, letterSpacing: -0.5),
    headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 32 / 24, letterSpacing: -0.3),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 28 / 20),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 24 / 18),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 22 / 16),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, height: 24 / 16),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, height: 20 / 14),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, height: 16 / 12),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 20 / 14),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 16 / 12),
    labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, height: 14 / 10),
  );

  // --- 亮色排版（同暗色，颜色由 ThemeData.colorScheme 控制）---
  static TextTheme lightTextTheme() => darkTextTheme();
}

/// Bento 间距令牌
/// 基于 8 点网格系统
class BentoSpacing {
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;
}

/// Bento 圆角令牌
class BentoRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// 生成亮色主题
ThemeData bentoLightTheme() {
  const colors = BentoColors.light;
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: colors.background,
    primaryColor: colors.primary,
    colorScheme: ColorScheme.light(
      primary: colors.primary,
      secondary: colors.success,
      surface: colors.surface,
      error: colors.error,
      onSurface: colors.textPrimary,
    ),
    extensions: const [colors],
    textTheme: BentoTypography.lightTextTheme().apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    ),
    // 卡片
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BentoRadius.md),
      ),
      margin: EdgeInsets.zero,
    ),
    // 输入框
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        borderSide: BorderSide(color: colors.error),
      ),
      hintStyle: TextStyle(color: colors.textTertiary),
    ),
    // 分割线
    dividerTheme: DividerThemeData(
      color: colors.divider,
      thickness: 1,
      space: 1,
    ),
    // 底部导航栏
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.navBarBg,
      indicatorColor: colors.primaryLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary);
        }
        return TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: colors.textTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colors.primary, size: 24);
        }
        return IconThemeData(color: colors.textTertiary, size: 24);
      }),
    ),
    // 底部弹窗
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
      ),
    ),
    // 对话框
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BentoRadius.lg),
      ),
    ),
    // 浮动操作按钮
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: colors.textOnPrimary,
    ),
  );
}

/// 生成暗色主题
ThemeData bentoDarkTheme() {
  const colors = BentoColors.dark;
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: colors.background,
    primaryColor: colors.primary,
    colorScheme: ColorScheme.dark(
      primary: colors.primary,
      secondary: colors.success,
      surface: colors.surface,
      error: colors.error,
      onSurface: colors.textPrimary,
    ),
    extensions: const [colors],
    textTheme: BentoTypography.darkTextTheme().apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BentoRadius.md),
        side: BorderSide(color: colors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BentoRadius.sm),
        borderSide: BorderSide(color: colors.error),
      ),
      hintStyle: TextStyle(color: colors.textTertiary),
    ),
    dividerTheme: DividerThemeData(
      color: colors.divider,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.navBarBg,
      indicatorColor: colors.primaryLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary);
        }
        return TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: colors.textTertiary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colors.primary, size: 24);
        }
        return IconThemeData(color: colors.textTertiary, size: 24);
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BentoRadius.lg)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BentoRadius.lg),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: colors.textOnPrimary,
    ),
  );
}
