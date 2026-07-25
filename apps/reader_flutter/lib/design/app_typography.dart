import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// UI chrome typography (DM Sans). Reader body uses Ethiopic families separately.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(TextTheme base) {
    final sans = GoogleFonts.dmSansTextTheme(base);
    return sans.copyWith(
      displayLarge: sans.displayLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineLarge: sans.headlineLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineMedium: sans.headlineMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: sans.headlineSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: sans.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      titleMedium: sans.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        letterSpacing: -0.2,
      ),
      titleSmall: sans.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      bodyLarge: sans.bodyLarge?.copyWith(
        color: AppColors.textPrimary,
        fontSize: 16,
        height: 1.5,
      ),
      bodyMedium: sans.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        fontSize: 15,
        height: 1.45,
      ),
      bodySmall: sans.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: sans.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      labelMedium: sans.labelMedium?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      labelSmall: sans.labelSmall?.copyWith(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    );
  }

  static TextStyle get heroMetricValue => GoogleFonts.dmSans(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -1,
        height: 1,
      );

  static TextStyle get statTileValue => GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.05,
      );

  static TextStyle get sectionTitle => GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  /// Modern Amharic wordmark — clean sans, open tracking, medium weight.
  static TextStyle brandWordmark({
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w600,
    double height = 1.05,
    double letterSpacing = 0.6,
  }) {
    return GoogleFonts.notoSansEthiopic(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Smaller secondary line under the primary brand word.
  static TextStyle brandWordmarkCaption({
    required double fontSize,
    required Color color,
  }) {
    return GoogleFonts.notoSansEthiopic(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.1,
      letterSpacing: 1.4,
    );
  }
}
