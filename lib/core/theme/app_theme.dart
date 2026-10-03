import 'package:flutter/material.dart';

/// Tema Flutter — meniru persis `resources/css/app.css` (Tailwind v4 @theme)
/// Warung Lupi **v2** (sky-blue accent, border-first, shadow hampir nol).
///
/// Token warna dari app.css v2:
/// background #F4F5F6, surface #FFFFFF, border #E2E4E8,
/// text-main #14171C, text-muted #667085,
/// brand-600 #0284C7 (primary sky), brand-700 #0369A1 (hover),
/// ink #14171C (secondary near-black), warning #B45309 (hutang).
abstract final class AppColors {
  static const background = Color(0xFFF4F5F6);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E4E8);
  static const borderStrong = Color(0xFFD4D7DC);
  static const textMain = Color(0xFF14171C);
  static const textMuted = Color(0xFF667085);

  /// Hover baris list (web: hover:bg-[#F7F8FA] / #F1F2F4).
  static const hoverBg = Color(0xFFF7F8FA);
  static const chipBg = Color(0xFFF1F2F4);
  static const skeleton = Color(0xFFE8EAEE);

  // Brand (sky blue)
  static const brand50 = Color(0xFFF0F9FF);
  static const brand100 = Color(0xFFE0F2FE);
  static const brand200 = Color(0xFFBAE6FD);
  static const brand300 = Color(0xFF7DD3FC);
  static const brand400 = Color(0xFF38BDF8);
  static const brand500 = Color(0xFF0EA5E9);
  static const brand600 = Color(0xFF0284C7);
  static const brand700 = Color(0xFF0369A1);
  static const brand800 = Color(0xFF075985);
  static const brand900 = Color(0xFF0C4A6E);

  // Secondary: near-black (ink)
  static const ink = Color(0xFF14171C);
  static const inkSoft = Color(0xFF232830);

  // Semantic
  static const successBg = Color(0xFFDCFCE7);
  static const successText = Color(0xFF15803D);
  static const successBorder = Color(0xFFBBF7D0);
  static const warningBg = Color(0xFFFEF3C7);
  static const warningText = Color(0xFFB45309);
  static const warningBorder = Color(0xFFFDE68A);
  static const dangerBg = Color(0xFFFEE2E2);
  static const dangerText = Color(0xFFDC2626);
  static const dangerBorder = Color(0xFFFECACA);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF14171C);
}

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand600,
        primary: AppColors.brand600,
        secondary: AppColors.gray900,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.brand500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.dangerText),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.dangerText, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand600,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
