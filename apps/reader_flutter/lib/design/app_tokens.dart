import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Ethiopian sacred aesthetic palette.
  static const Color referencePrimary = Color(0xFF5B3B8C);      // ecclesiastical violet
  static const Color referenceAccent = Color(0xFFD4A017);        // Ethiopian gold
  static const Color referenceSurfaceAccent = Color(0xFFFDF3D0); // gold tint surface
  static const Color referenceSecondary = Color(0xFF8B1A1A);     // deep crimson
  static const Color referencePageBg = Color(0xFFFAF7F2);        // warm parchment

  /// Reader theme tokens.
  static const Color primary = referencePrimary;
  static const Color primaryDeep = Color(0xFF3B2460);
  static const Color accent = referenceAccent;
  static const Color background = Color(0xFFFFFDF9);   // warm off-white
  static const Color surfaceSoft = referencePageBg;
  static const Color surfaceCard = Colors.white;
  static const Color surfaceStrong = Color(0xFFF0EBE3); // warm tone
  static const Color border = Color(0xFFE5DDD0);        // warm hairline
  static const Color textPrimary = Color(0xFF1A1008);   // warm near-black
  static const Color textSecondary = Color(0xFF5C4E3A); // warm mid-brown

  /// Semantic tokens.
  static const Color errorSurface = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFF87171);
  static const Color successSurface = Color(0xFFF0FDF4);
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
