import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MY FARM colour system — soil & leaf, built for Ugandan farmers + pitch.
class AppColors {
  static const soil = Color(0xFF1D160F);
  static const soil2 = Color(0xFF2A1F15);
  static const card = Color(0xFF332518);
  static const leaf = Color(0xFF7CB342);
  static const leafBright = Color(0xFF9CCC65);
  static const gold = Color(0xFFE8A33D);
  static const cream = Color(0xFFF4ECD8);
  static const creamDim = Color(0xFFC9B896);
  static const rust = Color(0xFFC75B39);
  static const water = Color(0xFF4FB0D4);
  static const line = Color(0x1FF4ECD8); // cream @ ~12%
}

class AppText {
  static TextStyle display(double size,
          {FontWeight weight = FontWeight.w800, Color? color, double spacing = -0.5}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.cream,
        letterSpacing: spacing,
        height: 1.05,
      );

  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w400, Color? color, double height = 1.45}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.cream,
        height: height,
      );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.soil,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.leaf,
      secondary: AppColors.gold,
      surface: AppColors.card,
      error: AppColors.rust,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  );
}
