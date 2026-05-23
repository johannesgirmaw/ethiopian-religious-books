import 'package:flutter/material.dart';

// ─── Color System ────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand — Ethiopian sacred palette
  static const Color referencePrimary     = Color(0xFF5B3B8C); // ecclesiastical violet
  static const Color referenceAccent      = Color(0xFFE8B84B); // enriched gold
  static const Color referenceSurfaceAccent = Color(0xFFFDF3D0);
  static const Color referenceSecondary   = Color(0xFFC1272D); // Axumite crimson
  static const Color referencePageBg      = Color(0xFFFAF7F2); // warm parchment

  // Semantic aliases
  static const Color primary      = referencePrimary;
  static const Color primaryDeep  = Color(0xFF2D1B69); // very deep violet
  static const Color primaryMid   = Color(0xFF7C59C0); // mid violet
  static const Color accent       = referenceAccent;
  static const Color crimson      = referenceSecondary;

  // Surfaces
  static const Color background    = Color(0xFFFFFDF9); // warm off-white
  static const Color surfaceSoft   = referencePageBg;
  static const Color surfaceCard   = Colors.white;
  static const Color surfaceStrong = Color(0xFFF0EBE3);

  // Borders
  static const Color border       = Color(0xFFE5DDD0);
  static const Color borderSubtle = Color(0xFFF0EBE3);

  // Text
  static const Color textPrimary   = Color(0xFF1A1008);
  static const Color textSecondary = Color(0xFF5C4E3A);
  static const Color textTertiary  = Color(0xFF9C8E7C);
  static const Color textInverse   = Colors.white;

  // Semantic
  static const Color errorSurface  = Color(0xFFFEF2F2);
  static const Color errorBorder   = Color(0xFFF87171);
  static const Color successSurface = Color(0xFFF0FDF4);
  static const Color successBorder  = Color(0xFF6EE7B7);
}

// ─── Gradient Library ────────────────────────────────────────────────────────

class AppGradients {
  AppGradients._();

  // Primary hero: deep violet → violet → warm burgundy
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D1B69), Color(0xFF5B3B8C), Color(0xFF7B3A52)],
    stops: [0.0, 0.58, 1.0],
  );

  // Vertical hero for headers
  static const LinearGradient heroVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2D1B69), Color(0xFF5B3B8C)],
  );

  // Subtle card gradient
  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, Color(0xFFFAF7F2)],
  );

  // Gold accent
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8B84B), Color(0xFFD4A017)],
  );

  // Crimson accent
  static const LinearGradient crimson = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC1272D), Color(0xFF8B1A1A)],
  );

  // Splash radial — concentric rings on near-black
  static const RadialGradient splashRadial = RadialGradient(
    center: Alignment.center,
    radius: 1.4,
    colors: [Color(0xFF3B2460), Color(0xFF1A0E2E), Color(0xFF070412)],
    stops: [0.0, 0.55, 1.0],
  );

  // Frosted surface
  static LinearGradient frostedSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.92),
      Colors.white.withValues(alpha: 0.82),
    ],
  );
}

// ─── Shadow System ───────────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF5B3B8C).withValues(alpha: 0.08),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: const Color(0xFF5B3B8C).withValues(alpha: 0.14),
          blurRadius: 32,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get goldGlow => [
        BoxShadow(
          color: const Color(0xFFE8B84B).withValues(alpha: 0.55),
          blurRadius: 28,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFFE8B84B).withValues(alpha: 0.20),
          blurRadius: 60,
          spreadRadius: 8,
        ),
      ];

  static List<BoxShadow> get floatingBtn => [
        BoxShadow(
          color: const Color(0xFF5B3B8C).withValues(alpha: 0.45),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get modal => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 48,
          offset: const Offset(0, 20),
        ),
      ];
}

// ─── Spacing ─────────────────────────────────────────────────────────────────

class AppSpace {
  AppSpace._();

  static const double xxs  = 4;
  static const double xs   = 8;
  static const double sm   = 12;
  static const double md   = 16;
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 48;
}

// ─── Radius ──────────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();

  static const double xs   = 8;
  static const double sm   = 12;
  static const double md   = 16;
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double pill = 999;
}

// ─── Motion ──────────────────────────────────────────────────────────────────

class AppMotion {
  AppMotion._();

  static const Duration fast   = Duration(milliseconds: 120);
  static const Duration short  = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow   = Duration(milliseconds: 380);
}
