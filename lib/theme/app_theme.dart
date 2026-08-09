import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.neutral12,
      cardColor: AppColors.neutral11,
      primaryColor: AppColors.primaryBase,
      cardTheme: CardThemeData(
        color: AppColors.neutral11,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.neutral10, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.neutral12,
        foregroundColor: AppColors.neutral0,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBase,
        secondary: AppColors.primaryAccent,
        surface: AppColors.neutral11,
        error: AppColors.dangerBase,
      ),
      textTheme: GoogleFonts.googleSansTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: AppColors.neutral2,
          displayColor: AppColors.neutral0,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.neutral11,
        modalBackgroundColor: AppColors.neutral11,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.neutral11,
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.neutral13, width: 1),
        ),
      ),
    );
  }
}
