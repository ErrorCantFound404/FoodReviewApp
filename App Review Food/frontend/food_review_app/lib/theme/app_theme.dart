import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Minimalist 3-Color Scheme Palette
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color pitchBlack = Color(0xFF0F0F12);
  static const Color fireCoral = Color(0xFFFF453A); // Chosen Accent Color

  // Neutral Tones for UI Depth
  static const Color darkCardBg = Color(0xFF18181C);
  static const Color lightCardBg = Color(0xFFF7F7FA);
  static const Color grayBorder = Color(0xFFE5E5EA);
  static const Color darkGrayBorder = Color(0xFF2C2C30);
  static const Color textMutedLight = Color(0xFF8E8E93);
  static const Color textMutedDark = Color(0xFFA1A1A6);

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: pureWhite,
    primaryColor: pitchBlack,
    colorScheme: const ColorScheme.light(
      primary: pitchBlack,
      secondary: fireCoral,
      surface: pureWhite,
      onPrimary: pureWhite,
      onSecondary: pureWhite,
      onSurface: pitchBlack,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: pureWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: pitchBlack),
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: pitchBlack,
        letterSpacing: -0.5,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: pitchBlack, letterSpacing: -1),
      headlineMedium: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: pitchBlack, letterSpacing: -0.5),
      titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: pitchBlack),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, color: pitchBlack),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: pitchBlack),
      labelLarge: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: pureWhite),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: lightCardBg,
      selectedColor: pitchBlack,
      secondarySelectedColor: fireCoral,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: grayBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: pitchBlack,
        foregroundColor: pureWhite,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: pitchBlack,
    primaryColor: pureWhite,
    colorScheme: const ColorScheme.dark(
      primary: pureWhite,
      secondary: fireCoral,
      surface: darkCardBg,
      onPrimary: pitchBlack,
      onSecondary: pureWhite,
      onSurface: pureWhite,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: pitchBlack,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: pureWhite),
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: pureWhite,
        letterSpacing: -0.5,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: pureWhite, letterSpacing: -1),
      headlineMedium: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: pureWhite, letterSpacing: -0.5),
      titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: pureWhite),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, color: pureWhite),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: pureWhite),
      labelLarge: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: pitchBlack),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkCardBg,
      selectedColor: pureWhite,
      secondarySelectedColor: fireCoral,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: darkGrayBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: pureWhite,
        foregroundColor: pitchBlack,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
