import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Reference app palette — `/home/teddy3/code/mobile/lib/utils/app_colors.dart`
  static const Color referencePrimary = Color(0xFF7FCAEF);
  static const Color referenceAccent = Color(0xFFFFDE9D); // shiroColor
  static const Color referenceSurfaceAccent = Color(0xFFFCF3C3); // accentColor
  static const Color referenceSecondary = Color(0xFFAD2B31);
  static const Color referencePageBg = Color(0xFFFAFAFA); // Colors.grey[50]

  /// Reader theme — same hues as reference for consistency.
  static const Color primary = referencePrimary;
  static const Color primaryDeep = Color(0xFF5AB0D9);
  static const Color background = Colors.white;
  static const Color surfaceSoft = referencePageBg;
  static const Color surfaceCard = Colors.white;
  static const Color surfaceStrong = Color(0xFFF0F0F0);
  static const Color border = Color(0xFFE5E5E5);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
}

class AppSpace {
  AppSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();

  static const double xs = 10;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

class AppMotion {
  AppMotion._();

  static const Duration short = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 260);
}
