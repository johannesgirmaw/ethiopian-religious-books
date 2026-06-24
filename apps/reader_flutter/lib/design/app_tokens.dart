import 'package:flutter/material.dart';

// ─── Color System ────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand — OUTPOST cyan palette
  static const Color referencePrimary     = Color(0xFF29B6E0); // vivid sky cyan
  static const Color referenceAccent      = Color(0xFFF5A623); // notification orange
  static const Color referenceSurfaceAccent = Color(0xFFEAF1F6); // selected-row tint
  static const Color referenceSecondary   = Color(0xFF1E9BC2); // deep cyan
  static const Color referencePageBg      = Color(0xFFF4F8FB); // cool app background

  // Semantic aliases
  static const Color primary      = referencePrimary;
  static const Color primaryDeep  = Color(0xFF14708F); // deep teal-blue
  static const Color primaryMid   = Color(0xFF5CCDEC); // light cyan
  static const Color accent       = referenceAccent;
  static const Color crimson      = Color(0xFFE53935); // logout / danger red

  // Surfaces
  static const Color background    = Color(0xFFF4F8FB); // cool off-white
  static const Color surfaceSoft   = referenceSurfaceAccent;
  static const Color surfaceCard   = Colors.white;
  static const Color surfaceStrong = Color(0xFFE3E8EC);

  // Borders
  static const Color border       = Color(0xFFE3E8EC);
  static const Color borderSubtle = Color(0xFFEEF2F5);

  // Text
  static const Color textPrimary   = Color(0xFF2B2F33);
  static const Color textSecondary = Color(0xFF5A6169);
  static const Color textTertiary  = Color(0xFF8A9199);
  static const Color textInverse   = Colors.white;

  // Semantic
  static const Color errorSurface  = Color(0xFFFEF2F2);
  static const Color errorBorder   = Color(0xFFF87171);
  static const Color errorText     = Color(0xFFE53935);
  static const Color successSurface = Color(0xFFF0FDF4);
  static const Color successBorder  = Color(0xFF6EE7B7);
  static const Color successText   = Color(0xFF27C24C);

  /// Hairline on cards (v2 kit `T.line`).
  static Color get line => textPrimary.withValues(alpha: 0.08);

  /// iOS-style filled inputs (auth).
  static const Color surfaceInput = Color(0xFFF2F2F7);
}

// ─── Gradient Library ────────────────────────────────────────────────────────

class AppGradients {
  AppGradients._();

  // Primary hero: deep teal → cyan → light cyan
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14708F), Color(0xFF29B6E0), Color(0xFF5CCDEC)],
    stops: [0.0, 0.58, 1.0],
  );

  // Vertical hero for headers
  static const LinearGradient heroVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF14708F), Color(0xFF29B6E0)],
  );

  // Subtle card gradient
  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, Color(0xFFF4F8FB)],
  );

  // Amber accent
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5A623), Color(0xFFE08E00)],
  );

  // Danger accent
  static const LinearGradient crimson = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
  );

  // Splash radial — concentric rings on deep teal
  static const RadialGradient splashRadial = RadialGradient(
    center: Alignment.center,
    radius: 1.4,
    colors: [Color(0xFF14708F), Color(0xFF0A3A4A), Color(0xFF041820)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Inset greeting card — max one per shell screen.
  static const LinearGradient greetingMesh = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14708F), Color(0xFF29B6E0), Color(0xFF5CCDEC)],
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
          color: const Color(0xFF29B6E0).withValues(alpha: 0.08),
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
          color: const Color(0xFF29B6E0).withValues(alpha: 0.14),
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
          color: const Color(0xFFF5A623).withValues(alpha: 0.55),
          blurRadius: 28,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFFF5A623).withValues(alpha: 0.20),
          blurRadius: 60,
          spreadRadius: 8,
        ),
      ];

  static List<BoxShadow> get floatingBtn => [
        BoxShadow(
          color: const Color(0xFF29B6E0).withValues(alpha: 0.45),
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

  /// White metric / panel cards (v2 `PanelV2`, `HeroMetric`).
  static List<BoxShadow> get panel => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 0,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 24,
          spreadRadius: -16,
          offset: const Offset(0, 8),
        ),
      ];

  /// List rows (`ListItem`).
  static List<BoxShadow> get listRow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          spreadRadius: -6,
          offset: const Offset(0, 2),
        ),
      ];

  /// Greeting strip elevation.
  static List<BoxShadow> get greeting => [
        BoxShadow(
          color: AppColors.primaryDeep.withValues(alpha: 0.35),
          blurRadius: 24,
          spreadRadius: -12,
          offset: const Offset(0, 10),
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

// ─── Page layout ─────────────────────────────────────────────────────────────

class AppLayout {
  AppLayout._();

  /// Horizontal gutter for tab shell pages — wider than default Material padding.
  static const double pageHorizontal = 22;

  static const double pageTop = 12;
  static const double pageBottom = 40;

  /// Space between major sections (e.g. greeting → dashboard).
  static const double sectionGap = 28;

  /// Space between related blocks within a section.
  static const double blockGap = 16;

  /// Space between list rows or grid metadata.
  static const double itemGap = 12;

  static const EdgeInsets page = EdgeInsets.fromLTRB(
    pageHorizontal,
    pageTop,
    pageHorizontal,
    pageBottom,
  );

  static const EdgeInsets pageHorizontalOnly =
      EdgeInsets.symmetric(horizontal: pageHorizontal);
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
  /// Greeting card, large panels.
  static const double greeting = 22;
  static const double cardV2 = 18;
  static const double panel = 20;
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
