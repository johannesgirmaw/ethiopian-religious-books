import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDeep = Color(0xFF1D4ED8);
  static const Color background = Colors.white;
  static const Color surfaceSoft = Color(0xFFEFF6FF);
  static const Color surfaceCard = Color(0xFFEAF3FF);
  static const Color surfaceStrong = Color(0xFFD9E9FF);
  static const Color border = Color(0xFFC4D7F2);
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
