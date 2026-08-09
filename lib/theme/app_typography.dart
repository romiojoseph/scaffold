import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextStyle _baseStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    try {
      return GoogleFonts.googleSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    } catch (_) {
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
  }

  static const double displayLargeSize = 45;
  static const double displayMediumSize = 40;
  static const double displaySmallSize = 36;
  static const double heading1Size = 32;
  static const double heading2Size = 28;
  static const double heading3Size = 25;
  static const double heading4Size = 22;
  static const double heading5Size = 20;
  static const double heading6Size = 18;
  static const double subtitleSize = 16;
  static const double bodySize = 14;
  static const double captionSize = 12;
  static const double labelSize = 11;
  static const double taglineSize = 10;

  static TextStyle displayLarge({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: displayLargeSize,
    fontWeight: fontWeight ?? FontWeight.bold,
    color: color,
    height: height,
  );

  static TextStyle displayMedium({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: displayMediumSize,
    fontWeight: fontWeight ?? FontWeight.bold,
    color: color,
    height: height,
  );

  static TextStyle displaySmall({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: displaySmallSize,
    fontWeight: fontWeight ?? FontWeight.bold,
    color: color,
    height: height,
  );

  static TextStyle heading1({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: heading1Size,
    fontWeight: fontWeight ?? FontWeight.bold,
    color: color,
    height: height,
  );

  static TextStyle heading2({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: heading2Size,
    fontWeight: fontWeight ?? FontWeight.bold,
    color: color,
    height: height,
  );

  static TextStyle heading3({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: heading3Size,
    fontWeight: fontWeight ?? FontWeight.bold,
    color: color,
    height: height,
  );

  static TextStyle heading4({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: heading4Size,
    fontWeight: fontWeight ?? FontWeight.w600,
    color: color,
    height: height,
  );

  static TextStyle heading5({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: heading5Size,
    fontWeight: fontWeight ?? FontWeight.w600,
    color: color,
    height: height,
  );

  static TextStyle heading6({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: heading6Size,
    fontWeight: fontWeight ?? FontWeight.w600,
    color: color,
    height: height,
  );

  static TextStyle subtitle({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: subtitleSize,
    fontWeight: fontWeight ?? FontWeight.normal,
    color: color,
    height: height,
  );

  static TextStyle body({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: bodySize,
    fontWeight: fontWeight ?? FontWeight.normal,
    color: color,
    height: height,
  );

  static TextStyle caption({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: captionSize,
    fontWeight: fontWeight ?? FontWeight.normal,
    color: color,
    height: height,
  );

  static TextStyle label({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: labelSize,
    fontWeight: fontWeight ?? FontWeight.w500,
    color: color,
    height: height,
  );

  static TextStyle tagline({
    Color? color,
    FontWeight? fontWeight,
    double? height,
  }) => _baseStyle(
    fontSize: taglineSize,
    fontWeight: fontWeight ?? FontWeight.w500,
    color: color,
    height: height,
  );
}
