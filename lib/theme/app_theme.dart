import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MY FARM colour system: a light theme for reading outdoors in bright sun.
/// Every text colour here has at least 4.5:1 contrast on white.
class AppColors {
  // Semantic tokens - use these in new code.
  static const bg = Color(0xFFF5F6F1); // page background, warm off-white
  static const surface = Color(0xFFFFFFFF); // cards
  static const surfaceAlt = Color(0xFFEEF2E8); // icon tiles, subtle fills
  static const text = Color(0xFF18241A);
  static const textDim = Color(0xFF5E6B60);
  static const border = Color(0xFFE0E5DA);
  static const primary = Color(0xFF2E7D32); // leaf green
  static const primarySoft = Color(0xFFE3F1DF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const accent = Color(0xFF9A5B0B); // harvest gold, readable as text
  static const accentSoft = Color(0xFFFBEFD9);
  static const danger = Color(0xFFB3412B);
  static const dangerSoft = Color(0xFFF8E4DE);
  static const info = Color(0xFF17708F);

  // Older names from the dark theme, mapped onto the light palette so every
  // screen reads correctly while it is moved to the tokens above.
  static const soil = bg; // also used for icons/text on green fills
  static const soil2 = bg;
  static const card = surface;
  static const cream = text;
  static const creamDim = textDim;
  static const line = border;
  static const leaf = primary;
  static const leafBright = primary;
  static const gold = accent;
  static const rust = danger;
  static const water = info;
}

class AppText {
  static TextStyle display(double size,
          {FontWeight weight = FontWeight.w800,
          Color? color,
          double spacing = -0.5}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        letterSpacing: spacing,
        height: 1.1,
      );

  static TextStyle body(double size,
          {FontWeight weight = FontWeight.w400,
          Color? color,
          double height = 1.45}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        height: height,
      );
}

ThemeData buildTheme() {
  final text = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
      outline: AppColors.border,
    ),
    textTheme:
        text.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    dividerColor: AppColors.border,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textDim,
          )),
      labelTextStyle:
          WidgetStateProperty.resolveWith((states) => GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.textDim,
              )),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.text,
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
  );
}
