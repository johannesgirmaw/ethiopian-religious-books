import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Typography for immersive reader surfaces (Ethiopic + Latin).
class ReaderTypography {
  ReaderTypography._();

  static String? get _serifFamily =>
      GoogleFonts.notoSerifEthiopic().fontFamily;

  static TextStyle body({
    required double fontSize,
    required Color color,
    double height = 1.55,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.notoSerifEthiopic(
      fontSize: fontSize,
      height: height,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: 0.15,
    );
  }

  static TextStyle chapterTitle({
    required Color color,
    double fontSize = 15,
  }) {
    return TextStyle(
      fontFamily: _serifFamily,
      fontSize: fontSize,
      height: 1.25,
      color: color,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle chapterMeta({
    required Color color,
    double fontSize = 13,
  }) {
    return TextStyle(
      fontFamily: _serifFamily,
      fontSize: fontSize,
      height: 1.3,
      color: color,
      fontStyle: FontStyle.italic,
    );
  }

  static TextStyle labelCaps({
    required Color color,
  }) {
    return TextStyle(
      fontSize: 10,
      letterSpacing: 1.35,
      color: color,
      fontWeight: FontWeight.w600,
    );
  }

  static Color paperText(bool dark) =>
      dark ? const Color(0xFFE6EDF7) : AppColors.textPrimary;

  static Color paperMuted(bool dark) =>
      dark ? const Color(0xFF93A1B5) : AppColors.textSecondary;

  static Color paperBackground(String mode) {
    switch (mode) {
      case 'dark':
        return const Color(0xFF0F141B);
      case 'sepia':
        return const Color(0xFF29B6E0);
      default:
        return Colors.white;
    }
  }
}
