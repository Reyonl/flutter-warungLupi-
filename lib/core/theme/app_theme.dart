import 'package:flutter/material.dart';

/// Tema Flutter — meniru persis `resources/css/app.css` (Tailwind theme) Warung Lupi.
///
/// Token warna dari app.css:
/// background #F7F7F5, surface #FFFFFF, border #E5E5E5,
/// text-main #171717, text-muted #737373,
/// brand-600 #EA580C (primary), brand-700 #C2410C (hover),
/// brand-50 #fff7ed (aksen tipis), brand-100 #ffedd5, brand-200 #fed7aa.
abstract final class AppColors {
  static const background = Color(0xFFF7F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E5E5);
  static const borderStrong = Color(0xFFD1D5DB);
  static const textMain = Color(0xFF171717);
  static const textMuted = Color(0xFF737373);

  // Brand (oranye rust/terracotta)
  static const brand50 = Color(0xFFFFF7ED);
  static const brand100 = Color(0xFFFFEDD5);
  static const brand200 = Color(0xFFFED7AA);
  static const brand300 = Color(0xFFFDBA74);
  static const brand500 = Color(0xFFF97316);
  static const brand600 = Color(0xFFEA580C);
  static const brand700 = Color(0xFFC2410C);
  static const brand800 = Color(0xFF9A3412);

  // Semantic
  static const successBg = Color(0xFFDCFCE7);
  static const successText = Color(0xFF15803D);
  static const successBorder = Color(0xFFBBF7D0);
  static const dangerBg = Color(0xFFFEE2E2);
  static const dangerText = Color(0xFFDC2626);
  static const dangerBorder = Color(0xFFFECACA);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF171717);
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
          borderRadius: BorderRadius.all(Radius.circular(8)),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          borderSide: const BorderSide(color: AppColors.textMuted, width: 1.5),
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